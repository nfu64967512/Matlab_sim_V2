"""
Python-MATLAB整合橋接器
實現MATLAB無人機群飛模擬器與Python生態系統的無縫整合

支援功能:
- MAVLink協議解析和生成
- ROS2節點通信
- 實時數據流處理
- GPU計算加速
- 網路通信接口
"""

import numpy as np
import matlab.engine
import asyncio
import threading
import queue
import json
import time
import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Callable, Any, Tuple
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
import websockets
import zmq

# 嘗試導入可選依賴
try:
    import rclpy
    from rclpy.node import Node
    from geometry_msgs.msg import Point, Quaternion, Pose, PoseStamped
    from nav_msgs.msg import Path
    from std_msgs.msg import String, Header
    ROS2_AVAILABLE = True
except ImportError:
    ROS2_AVAILABLE = False
    print("⚠️ ROS2不可用，相關功能將被禁用")

try:
    from pymavlink import mavutil
    from pymavlink.dialects.v20 import common as mavlink
    MAVLINK_AVAILABLE = True
except ImportError:
    MAVLINK_AVAILABLE = False
    print("⚠️ MAVLink不可用，相關功能將被禁用")

try:
    import cupy as cp
    CUPY_AVAILABLE = True
except ImportError:
    CUPY_AVAILABLE = False

# 設置日誌
logging.basicConfig(level=logging.INFO,
                   format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class DroneState:
    """無人機狀態數據類"""
    drone_id: str
    timestamp: float
    position: np.ndarray = field(default_factory=lambda: np.zeros(3))
    velocity: np.ndarray = field(default_factory=lambda: np.zeros(3))
    attitude: np.ndarray = field(default_factory=lambda: np.zeros(3))  # roll, pitch, yaw
    battery_voltage: float = 0.0
    flight_mode: str = "UNKNOWN"
    armed: bool = False
    gps_fix: int = 0

@dataclass
class MissionWaypoint:
    """任務航點數據類"""
    sequence: int
    lat: float
    lon: float
    alt: float
    command: int = 16  # MAV_CMD_NAV_WAYPOINT
    param1: float = 0.0
    param2: float = 0.0
    param3: float = 0.0
    param4: float = 0.0
    autocontinue: bool = True

class MATLABBridge:
    """MATLAB引擎橋接器"""
    
    def __init__(self, matlab_path: Optional[str] = None):
        self.engine = None
        self.matlab_path = matlab_path
        self.is_connected = False
        self._lock = threading.Lock()
        
    def connect(self) -> bool:
        """連接到MATLAB引擎"""
        try:
            logger.info("🔗 正在連接MATLAB引擎...")
            
            if self.matlab_path:
                self.engine = matlab.engine.start_matlab(f"-sd {self.matlab_path}")
            else:
                self.engine = matlab.engine.start_matlab()
            
            # 測試連接
            result = self.engine.eval('1+1')
            if result == 2.0:
                self.is_connected = True
                logger.info("✅ MATLAB引擎連接成功")
                return True
            else:
                raise Exception("MATLAB引擎測試失敗")
                
        except Exception as e:
            logger.error(f"❌ MATLAB引擎連接失敗: {e}")
            self.is_connected = False
            return False
    
    def disconnect(self):
        """斷開MATLAB引擎連接"""
        if self.engine:
            try:
                self.engine.quit()
                logger.info("🔌 MATLAB引擎已斷開")
            except:
                pass
        self.is_connected = False
    
    def call_function(self, func_name: str, *args, **kwargs) -> Any:
        """調用MATLAB函數"""
        if not self.is_connected:
            raise Exception("MATLAB引擎未連接")
        
        with self._lock:
            try:
                matlab_func = getattr(self.engine, func_name)
                return matlab_func(*args, **kwargs)
            except Exception as e:
                logger.error(f"MATLAB函數調用失敗 {func_name}: {e}")
                raise
    
    def evaluate(self, expression: str) -> Any:
        """執行MATLAB表達式"""
        if not self.is_connected:
            raise Exception("MATLAB引擎未連接")
        
        with self._lock:
            try:
                return self.engine.eval(expression)
            except Exception as e:
                logger.error(f"MATLAB表達式執行失敗: {e}")
                raise

class MAVLinkInterface:
    """MAVLink協議接口"""
    
    def __init__(self, connection_string: str = "udp:localhost:14550"):
        self.connection_string = connection_string
        self.connection = None
        self.is_connected = False
        self.message_handlers: Dict[str, List[Callable]] = {}
        self.running = False
        self._thread = None
        
        if not MAVLINK_AVAILABLE:
            logger.warning("MAVLink不可用，接口將無法工作")
    
    def connect(self) -> bool:
        """連接MAVLink"""
        if not MAVLINK_AVAILABLE:
            return False
        
        try:
            logger.info(f"🔗 正在連接MAVLink: {self.connection_string}")
            self.connection = mavutil.mavlink_connection(self.connection_string)
            
            # 等待心跳包
            logger.info("等待心跳包...")
            heartbeat = self.connection.wait_heartbeat(timeout=10)
            if heartbeat:
                self.is_connected = True
                logger.info("✅ MAVLink連接成功")
                
                # 啟動消息處理線程
                self.running = True
                self._thread = threading.Thread(target=self._message_loop, daemon=True)
                self._thread.start()
                
                return True
            else:
                logger.error("未收到心跳包")
                return False
                
        except Exception as e:
            logger.error(f"❌ MAVLink連接失敗: {e}")
            return False
    
    def disconnect(self):
        """斷開MAVLink連接"""
        self.running = False
        if self._thread:
            self._thread.join(timeout=5)
        
        if self.connection:
            self.connection.close()
        
        self.is_connected = False
        logger.info("🔌 MAVLink已斷開")
    
    def register_handler(self, message_type: str, handler: Callable):
        """註冊消息處理器"""
        if message_type not in self.message_handlers:
            self.message_handlers[message_type] = []
        self.message_handlers[message_type].append(handler)
    
    def send_waypoint_mission(self, waypoints: List[MissionWaypoint], target_system: int = 1, target_component: int = 1):
        """發送航點任務"""
        if not self.is_connected or not MAVLINK_AVAILABLE:
            return False
        
        try:
            # 清除現有任務
            self.connection.mav.mission_clear_all_send(target_system, target_component)
            
            # 發送任務計數
            self.connection.mav.mission_count_send(target_system, target_component, len(waypoints))
            
            # 發送每個航點
            for i, wp in enumerate(waypoints):
                self.connection.mav.mission_item_send(
                    target_system,
                    target_component,
                    wp.sequence,
                    mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT,
                    wp.command,
                    0,  # current
                    wp.autocontinue,
                    wp.param1, wp.param2, wp.param3, wp.param4,
                    wp.lat, wp.lon, wp.alt
                )
            
            logger.info(f"✅ 已發送{len(waypoints)}個航點任務")
            return True
            
        except Exception as e:
            logger.error(f"❌ 發送航點任務失敗: {e}")
            return False
    
    def request_drone_state(self, target_system: int = 1):
        """請求無人機狀態"""
        if not self.is_connected or not MAVLINK_AVAILABLE:
            return
        
        # 請求位置和姿態信息
        self.connection.mav.request_data_stream_send(
            target_system, 1,
            mavlink.MAV_DATA_STREAM_POSITION,
            10, 1  # 10Hz
        )
        
        self.connection.mav.request_data_stream_send(
            target_system, 1,
            mavlink.MAV_DATA_STREAM_EXTRA1,
            10, 1  # 包含姿態信息
        )
    
    def _message_loop(self):
        """消息處理循環"""
        while self.running and self.connection:
            try:
                msg = self.connection.recv_match(timeout=1.0)
                if msg:
                    msg_type = msg.get_type()
                    
                    # 調用註冊的處理器
                    if msg_type in self.message_handlers:
                        for handler in self.message_handlers[msg_type]:
                            try:
                                handler(msg)
                            except Exception as e:
                                logger.error(f"消息處理器錯誤: {e}")
                
            except Exception as e:
                logger.error(f"消息接收錯誤: {e}")
                break

class ROS2Bridge:
    """ROS2橋接器"""
    
    def __init__(self, node_name: str = "drone_sim_bridge"):
        self.node_name = node_name
        self.node = None
        self.is_initialized = False
        self.publishers = {}
        self.subscribers = {}
        self.running = False
        self._executor = None
        self._thread = None
        
        if not ROS2_AVAILABLE:
            logger.warning("ROS2不可用，橋接器將無法工作")
    
    def initialize(self) -> bool:
        """初始化ROS2節點"""
        if not ROS2_AVAILABLE:
            return False
        
        try:
            logger.info("🔗 正在初始化ROS2節點...")
            
            rclpy.init()
            self.node = Node(self.node_name)
            self.is_initialized = True
            
            # 創建執行器
            self._executor = rclpy.executors.SingleThreadedExecutor()
            self._executor.add_node(self.node)
            
            # 啟動執行線程
            self.running = True
            self._thread = threading.Thread(target=self._spin_loop, daemon=True)
            self._thread.start()
            
            logger.info("✅ ROS2節點初始化成功")
            return True
            
        except Exception as e:
            logger.error(f"❌ ROS2初始化失敗: {e}")
            return False
    
    def shutdown(self):
        """關閉ROS2節點"""
        self.running = False
        if self._thread:
            self._thread.join(timeout=5)
        
        if self.is_initialized:
            if self._executor:
                self._executor.shutdown()
            if self.node:
                self.node.destroy_node()
            rclpy.shutdown()
        
        logger.info("🔌 ROS2節點已關閉")
    
    def create_publisher(self, topic: str, msg_type, qos_depth: int = 10):
        """創建發布者"""
        if not self.is_initialized:
            return None
        
        publisher = self.node.create_publisher(msg_type, topic, qos_depth)
        self.publishers[topic] = publisher
        logger.info(f"📡 創建發布者: {topic}")
        return publisher
    
    def create_subscriber(self, topic: str, msg_type, callback, qos_depth: int = 10):
        """創建訂閱者"""
        if not self.is_initialized:
            return None
        
        subscriber = self.node.create_subscription(msg_type, topic, callback, qos_depth)
        self.subscribers[topic] = subscriber
        logger.info(f"📡 創建訂閱者: {topic}")
        return subscriber
    
    def publish_drone_path(self, topic: str, waypoints: List[Tuple[float, float, float]]):
        """發布無人機路徑"""
        if topic not in self.publishers:
            self.create_publisher(topic, Path)
        
        path_msg = Path()
        path_msg.header = Header()
        path_msg.header.frame_id = "map"
        path_msg.header.stamp = self.node.get_clock().now().to_msg()
        
        for x, y, z in waypoints:
            pose_stamped = PoseStamped()
            pose_stamped.header = path_msg.header
            pose_stamped.pose.position = Point(x=x, y=y, z=z)
            pose_stamped.pose.orientation = Quaternion(w=1.0)
            path_msg.poses.append(pose_stamped)
        
        self.publishers[topic].publish(path_msg)
    
    def _spin_loop(self):
        """執行器循環"""
        while self.running and rclpy.ok():
            try:
                self._executor.spin_once(timeout_sec=0.1)
            except Exception as e:
                logger.error(f"ROS2執行錯誤: {e}")
                break

class WebSocketServer:
    """WebSocket服務器 - 用於實時數據傳輸"""
    
    def __init__(self, host: str = "localhost", port: int = 8765):
        self.host = host
        self.port = port
        self.clients = set()
        self.running = False
        self.server = None
        
    async def register(self, websocket, path):
        """註冊客戶端"""
        self.clients.add(websocket)
        logger.info(f"📱 客戶端已連接: {websocket.remote_address}")
        
        try:
            await websocket.wait_closed()
        finally:
            self.clients.remove(websocket)
            logger.info(f"📱 客戶端已斷開: {websocket.remote_address}")
    
    async def broadcast_data(self, data: Dict):
        """廣播數據到所有客戶端"""
        if self.clients:
            message = json.dumps(data)
            disconnected = set()
            
            for client in self.clients:
                try:
                    await client.send(message)
                except websockets.exceptions.ConnectionClosed:
                    disconnected.add(client)
                except Exception as e:
                    logger.error(f"廣播錯誤: {e}")
                    disconnected.add(client)
            
            # 清理斷開的連接
            self.clients -= disconnected
    
    async def start_server(self):
        """啟動WebSocket服務器"""
        try:
            self.server = await websockets.serve(self.register, self.host, self.port)
            self.running = True
            logger.info(f"🌐 WebSocket服務器啟動: ws://{self.host}:{self.port}")
            
            # 保持服務器運行
            await self.server.wait_closed()
            
        except Exception as e:
            logger.error(f"❌ WebSocket服務器啟動失敗: {e}")
    
    def stop_server(self):
        """停止WebSocket服務器"""
        if self.server:
            self.server.close()
        self.running = False
        logger.info("🔌 WebSocket服務器已停止")

class ZMQCommunicator:
    """ZeroMQ通信器 - 用於高性能數據傳輸"""
    
    def __init__(self, port: int = 5555):
        self.context = zmq.Context()
        self.socket = None
        self.port = port
        self.running = False
        
    def setup_publisher(self):
        """設置發布者模式"""
        self.socket = self.context.socket(zmq.PUB)
        self.socket.bind(f"tcp://*:{self.port}")
        logger.info(f"📡 ZMQ發布者已啟動: tcp://*:{self.port}")
    
    def setup_subscriber(self, server_address: str = "localhost"):
        """設置訂閱者模式"""
        self.socket = self.context.socket(zmq.SUB)
        self.socket.connect(f"tcp://{server_address}:{self.port}")
        self.socket.setsockopt(zmq.SUBSCRIBE, b"")  # 訂閱所有消息
        logger.info(f"📡 ZMQ訂閱者已連接: tcp://{server_address}:{self.port}")
    
    def send_data(self, topic: str, data: Dict):
        """發送數據"""
        if self.socket and self.socket.socket_type == zmq.PUB:
            message = {
                'topic': topic,
                'timestamp': time.time(),
                'data': data
            }
            self.socket.send_string(json.dumps(message))
    
    def receive_data(self, timeout: int = 1000):
        """接收數據"""
        if self.socket and self.socket.socket_type == zmq.SUB:
            try:
                if self.socket.poll(timeout):
                    message = self.socket.recv_string()
                    return json.loads(message)
            except zmq.Again:
                pass  # 超時
            except Exception as e:
                logger.error(f"ZMQ接收錯誤: {e}")
        return None
    
    def close(self):
        """關閉通信器"""
        if self.socket:
            self.socket.close()
        self.context.term()
        logger.info("🔌 ZMQ通信器已關閉")

class DroneSimulationBridge:
    """主要的無人機模擬橋接器類"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        
        # 組件初始化
        self.matlab_bridge = MATLABBridge(self.config.get('matlab_path'))
        self.mavlink_interface = MAVLinkInterface(self.config.get('mavlink_connection', 'udp:localhost:14550'))
        self.ros2_bridge = ROS2Bridge(self.config.get('ros2_node_name', 'drone_sim_bridge'))
        self.websocket_server = WebSocketServer(
            self.config.get('websocket_host', 'localhost'),
            self.config.get('websocket_port', 8765)
        )
        self.zmq_communicator = ZMQCommunicator(self.config.get('zmq_port', 5555))
        
        # 數據存儲
        self.drone_states: Dict[str, DroneState] = {}
        self.mission_waypoints: Dict[str, List[MissionWaypoint]] = {}
        
        # 線程池
        self.thread_pool = ThreadPoolExecutor(max_workers=4)
        self.process_pool = ProcessPoolExecutor(max_workers=2) if CUPY_AVAILABLE else None
        
        # 數據處理隊列
        self.data_queue = queue.Queue(maxsize=1000)
        
        # 運行狀態
        self.running = False
        self.update_interval = 0.1  # 10Hz更新頻率
        
        logger.info("🌉 無人機模擬橋接器已初始化")
    
    async def start(self):
        """啟動橋接器"""
        logger.info("🚀 啟動無人機模擬橋接器...")
        
        # 連接MATLAB
        if not self.matlab_bridge.connect():
            logger.warning("MATLAB連接失敗，相關功能將受限")
        
        # 連接MAVLink
        if MAVLINK_AVAILABLE:
            if not self.mavlink_interface.connect():
                logger.warning("MAVLink連接失敗")
            else:
                # 註冊MAVLink消息處理器
                self.mavlink_interface.register_handler('GLOBAL_POSITION_INT', self._handle_mavlink_position)
                self.mavlink_interface.register_handler('ATTITUDE', self._handle_mavlink_attitude)
                self.mavlink_interface.register_handler('SYS_STATUS', self._handle_mavlink_status)
        
        # 初始化ROS2
        if ROS2_AVAILABLE:
            if not self.ros2_bridge.initialize():
                logger.warning("ROS2初始化失敗")
            else:
                # 創建ROS2發布者和訂閱者
                self.ros2_bridge.create_publisher('/drone_sim/paths', Path)
                self.ros2_bridge.create_subscriber('/drone_sim/commands', String, self._handle_ros2_command)
        
        # 設置ZMQ通信
        self.zmq_communicator.setup_publisher()
        
        self.running = True
        
        # 啟動主要處理循環和WebSocket服務器
        await asyncio.gather(
            self._main_loop(),
            self.websocket_server.start_server()
        )
    
    async def stop(self):
        """停止橋接器"""
        logger.info("🛑 正在停止無人機模擬橋接器...")
        
        self.running = False
        
        # 關閉各組件
        self.matlab_bridge.disconnect()
        self.mavlink_interface.disconnect()
        self.ros2_bridge.shutdown()
        self.websocket_server.stop_server()
        self.zmq_communicator.close()
        
        # 關閉線程池
        self.thread_pool.shutdown(wait=True)
        if self.process_pool:
            self.process_pool.shutdown(wait=True)
        
        logger.info("✅ 無人機模擬橋接器已停止")
    
    async def _main_loop(self):
        """主處理循環"""
        logger.info("🔄 主處理循環已啟動")
        
        while self.running:
            try:
                # 處理數據隊列
                self._process_data_queue()
                
                # 更新MATLAB模擬器
                await self._update_matlab_simulation()
                
                # 廣播數據到WebSocket客戶端
                await self._broadcast_simulation_data()
                
                # 發送數據到ZMQ
                self._send_zmq_data()
                
                # 更新ROS2主題
                self._update_ros2_topics()
                
                await asyncio.sleep(self.update_interval)
                
            except Exception as e:
                logger.error(f"主循環錯誤: {e}")
                await asyncio.sleep(1.0)
    
    def _process_data_queue(self):
        """處理數據隊列"""
        processed_count = 0
        
        while not self.data_queue.empty() and processed_count < 10:
            try:
                data_item = self.data_queue.get_nowait()
                self._process_data_item(data_item)
                processed_count += 1
            except queue.Empty:
                break
            except Exception as e:
                logger.error(f"數據處理錯誤: {e}")
    
    def _process_data_item(self, data_item: Dict):
        """處理單個數據項目"""
        data_type = data_item.get('type')
        
        if data_type == 'drone_state':
            self._update_drone_state(data_item['data'])
        elif data_type == 'mission_waypoint':
            self._update_mission_waypoints(data_item['data'])
        elif data_type == 'matlab_command':
            self._execute_matlab_command(data_item['data'])
    
    def _update_drone_state(self, state_data: Dict):
        """更新無人機狀態"""
        drone_id = state_data['drone_id']
        
        if drone_id not in self.drone_states:
            self.drone_states[drone_id] = DroneState(drone_id=drone_id, timestamp=time.time())
        
        state = self.drone_states[drone_id]
        state.timestamp = time.time()
        
        # 更新位置
        if 'position' in state_data:
            state.position = np.array(state_data['position'])
        
        # 更新速度
        if 'velocity' in state_data:
            state.velocity = np.array(state_data['velocity'])
        
        # 更新姿態
        if 'attitude' in state_data:
            state.attitude = np.array(state_data['attitude'])
        
        # 更新其他狀態
        for key in ['battery_voltage', 'flight_mode', 'armed', 'gps_fix']:
            if key in state_data:
                setattr(state, key, state_data[key])
    
    async def _update_matlab_simulation(self):
        """更新MATLAB模擬"""
        if not self.matlab_bridge.is_connected:
            return
        
        try:
            # 獲取當前模擬時間
            current_time = await asyncio.get_event_loop().run_in_executor(
                self.thread_pool,
                self.matlab_bridge.evaluate,
                'simulator.current_time'
            )
            
            # 更新模擬器狀態 (如果有新數據)
            if self.drone_states:
                state_data = {
                    drone_id: {
                        'position': state.position.tolist(),
                        'velocity': state.velocity.tolist(),
                        'attitude': state.attitude.tolist(),
                        'timestamp': state.timestamp
                    }
                    for drone_id, state in self.drone_states.items()
                }
                
                # 異步調用MATLAB更新函數
                await asyncio.get_event_loop().run_in_executor(
                    self.thread_pool,
                    self._update_matlab_drone_states,
                    state_data
                )
                
        except Exception as e:
            logger.error(f"MATLAB模擬更新錯誤: {e}")
    
    def _update_matlab_drone_states(self, state_data: Dict):
        """更新MATLAB中的無人機狀態"""
        try:
            # 將Python字典轉換為MATLAB可接受的格式
            json_str = json.dumps(state_data)
            self.matlab_bridge.evaluate(f"update_drone_states_from_python('{json_str}')")
        except Exception as e:
            logger.error(f"MATLAB狀態更新失敗: {e}")
    
    async def _broadcast_simulation_data(self):
        """廣播模擬數據"""
        if not self.websocket_server.clients:
            return
        
        try:
            # 準備廣播數據
            broadcast_data = {
                'timestamp': time.time(),
                'drone_states': {
                    drone_id: {
                        'position': state.position.tolist(),
                        'velocity': state.velocity.tolist(),
                        'attitude': state.attitude.tolist(),
                        'battery_voltage': state.battery_voltage,
                        'flight_mode': state.flight_mode,
                        'armed': state.armed
                    }
                    for drone_id, state in self.drone_states.items()
                }
            }
            
            # 獲取MATLAB模擬器數據
            if self.matlab_bridge.is_connected:
                matlab_data = await asyncio.get_event_loop().run_in_executor(
                    self.thread_pool,
                    self._get_matlab_simulation_data
                )
                broadcast_data['matlab_simulation'] = matlab_data
            
            # 廣播到WebSocket客戶端
            await self.websocket_server.broadcast_data(broadcast_data)
            
        except Exception as e:
            logger.error(f"廣播錯誤: {e}")
    
    def _get_matlab_simulation_data(self) -> Dict:
        """獲取MATLAB模擬數據"""
        try:
            # 獲取基本模擬信息
            current_time = self.matlab_bridge.evaluate('simulator.current_time')
            is_playing = self.matlab_bridge.evaluate('simulator.is_playing')
            
            return {
                'current_time': current_time,
                'is_playing': bool(is_playing),
                'drone_count': len(self.drone_states)
            }
        except Exception as e:
            logger.error(f"獲取MATLAB數據失敗: {e}")
            return {}
    
    def _send_zmq_data(self):
        """通過ZMQ發送數據"""
        try:
            if self.drone_states:
                zmq_data = {
                    'timestamp': time.time(),
                    'drone_count': len(self.drone_states),
                    'positions': {
                        drone_id: state.position.tolist()
                        for drone_id, state in self.drone_states.items()
                    }
                }
                
                self.zmq_communicator.send_data('simulation_update', zmq_data)
                
        except Exception as e:
            logger.error(f"ZMQ發送錯誤: {e}")
    
    def _update_ros2_topics(self):
        """更新ROS2主題"""
        if not ROS2_AVAILABLE or not self.ros2_bridge.is_initialized:
            return
        
        try:
            # 發布無人機路徑
            for drone_id, state in self.drone_states.items():
                topic = f'/drone_sim/{drone_id}/path'
                
                # 簡化的路徑數據 (只包含當前位置)
                waypoints = [tuple(state.position)]
                self.ros2_bridge.publish_drone_path(topic, waypoints)
                
        except Exception as e:
            logger.error(f"ROS2更新錯誤: {e}")
    
    # MAVLink消息處理器
    def _handle_mavlink_position(self, msg):
        """處理MAVLink位置消息"""
        drone_id = f"mavlink_{msg.get_srcSystem()}"
        
        position_data = {
            'drone_id': drone_id,
            'position': [
                msg.lat / 1e7,  # 緯度
                msg.lon / 1e7,  # 經度  
                msg.alt / 1000.0  # 高度 (轉換為米)
            ],
            'velocity': [
                msg.vx / 100.0,  # 速度 (cm/s -> m/s)
                msg.vy / 100.0,
                msg.vz / 100.0
            ]
        }
        
        self.data_queue.put({
            'type': 'drone_state',
            'data': position_data
        })
    
    def _handle_mavlink_attitude(self, msg):
        """處理MAVLink姿態消息"""
        drone_id = f"mavlink_{msg.get_srcSystem()}"
        
        attitude_data = {
            'drone_id': drone_id,
            'attitude': [
                msg.roll,
                msg.pitch,
                msg.yaw
            ]
        }
        
        self.data_queue.put({
            'type': 'drone_state',
            'data': attitude_data
        })
    
    def _handle_mavlink_status(self, msg):
        """處理MAVLink狀態消息"""
        drone_id = f"mavlink_{msg.get_srcSystem()}"
        
        status_data = {
            'drone_id': drone_id,
            'battery_voltage': msg.voltage_battery / 1000.0,  # mV -> V
            'armed': bool(msg.onboard_control_sensors_enabled & 0x80000000)
        }
        
        self.data_queue.put({
            'type': 'drone_state',
            'data': status_data
        })
    
    # ROS2消息處理器
    def _handle_ros2_command(self, msg):
        """處理ROS2命令消息"""
        try:
            command_data = json.loads(msg.data)
            
            self.data_queue.put({
                'type': 'matlab_command',
                'data': command_data
            })
            
        except Exception as e:
            logger.error(f"ROS2命令處理錯誤: {e}")
    
    def _execute_matlab_command(self, command_data: Dict):
        """執行MATLAB命令"""
        if not self.matlab_bridge.is_connected:
            return
        
        try:
            command_type = command_data.get('type')
            
            if command_type == 'start_simulation':
                self.matlab_bridge.call_function('start_simulation')
            elif command_type == 'stop_simulation':
                self.matlab_bridge.call_function('stop_simulation')
            elif command_type == 'load_mission':
                mission_file = command_data.get('file')
                self.matlab_bridge.call_function('load_qgc_file', mission_file)
            elif command_type == 'set_safety_distance':
                distance = command_data.get('distance', 5.0)
                self.matlab_bridge.evaluate(f'simulator.safety_distance = {distance}')
                
        except Exception as e:
            logger.error(f"MATLAB命令執行錯誤: {e}")
    
    # 公共API方法
    def add_drone_state(self, drone_id: str, position: List[float], 
                       velocity: List[float] = None, attitude: List[float] = None):
        """添加或更新無人機狀態"""
        state_data = {
            'drone_id': drone_id,
            'position': position
        }
        
        if velocity:
            state_data['velocity'] = velocity
        if attitude:
            state_data['attitude'] = attitude
        
        self.data_queue.put({
            'type': 'drone_state',
            'data': state_data
        })
    
    def send_mission_to_drone(self, drone_id: str, waypoints: List[MissionWaypoint]):
        """發送任務到無人機"""
        if MAVLINK_AVAILABLE and self.mavlink_interface.is_connected:
            # 通過MAVLink發送
            target_system = int(drone_id.split('_')[-1]) if '_' in drone_id else 1
            self.mavlink_interface.send_waypoint_mission(waypoints, target_system)
        
        # 存儲任務數據
        self.mission_waypoints[drone_id] = waypoints
        
        # 更新MATLAB模擬器
        self.data_queue.put({
            'type': 'mission_waypoint',
            'data': {
                'drone_id': drone_id,
                'waypoints': [
                    {
                        'sequence': wp.sequence,
                        'lat': wp.lat,
                        'lon': wp.lon,
                        'alt': wp.alt,
                        'command': wp.command
                    }
                    for wp in waypoints
                ]
            }
        })
    
    def get_drone_states(self) -> Dict[str, DroneState]:
        """獲取所有無人機狀態"""
        return self.drone_states.copy()
    
    def get_simulation_stats(self) -> Dict[str, Any]:
        """獲取模擬統計信息"""
        return {
            'connected_drones': len(self.drone_states),
            'matlab_connected': self.matlab_bridge.is_connected,
            'mavlink_connected': self.mavlink_interface.is_connected if MAVLINK_AVAILABLE else False,
            'ros2_initialized': self.ros2_bridge.is_initialized if ROS2_AVAILABLE else False,
            'websocket_clients': len(self.websocket_server.clients),
            'running': self.running
        }

# 使用示例和測試函數
async def demo_bridge_usage():
    """示例使用方式"""
    logger.info("🎬 開始橋接器演示...")
    
    # 創建橋接器配置
    config = {
        'matlab_path': '/path/to/your/matlab/workspace',
        'mavlink_connection': 'udp:localhost:14550',
        'ros2_node_name': 'demo_drone_bridge',
        'websocket_host': 'localhost',
        'websocket_port': 8765,
        'zmq_port': 5555
    }
    
    # 創建橋接器
    bridge = DroneSimulationBridge(config)
    
    try:
        # 啟動橋接器 (這會啟動所有服務)
        await bridge.start()
        
    except KeyboardInterrupt:
        logger.info("收到中斷信號，正在關閉...")
    except Exception as e:
        logger.error(f"演示錯誤: {e}")
    finally:
        await bridge.stop()

if __name__ == "__main__":
    # 運行演示
    asyncio.run(demo_bridge_usage())