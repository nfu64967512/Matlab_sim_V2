% EnhancedQuadrotorPhysics.m
% 增強版四旋翼物理模型 - 詳細可配置參數

classdef EnhancedQuadrotorPhysics < handle
    
    properties
        % 機架配置參數
        airframe_config
        
        % 推進系統參數
        propulsion_system
        
        % 電池系統參數
        battery_system
        
        % 感測器套件參數
        sensor_suite
        
        % 空氣動力學參數
        aerodynamics
        
        % 環境參數
        environment
        
        % 計算快取
        computation_cache
    end
    
    methods
        function obj = EnhancedQuadrotorPhysics(config_name)
            % 建構函數
            if nargin < 1
                config_name = 'standard';
            end
            
            fprintf('🔧 初始化增強物理參數模組...\n');
            obj.initialize_airframe_configs();
            obj.load_configuration(config_name);
            obj.validate_physics_parameters();
            obj.initialize_computation_cache();
            
            fprintf('✅ 物理參數模組初始化完成\n');
        end
        
        function initialize_airframe_configs(obj)
            % 初始化預設機架配置
            obj.airframe_config = containers.Map();
            
            % === DJI Phantom 4 風格配置 ===
            phantom_config = struct();
            phantom_config.name = 'DJI Phantom 4 類型';
            phantom_config.mass = 1.38;                    % 總重量 (kg)
            phantom_config.wheelbase = 0.35;               % 軸距 (m)  
            phantom_config.arm_length = 0.175;             % 臂長 (m)
            phantom_config.body_height = 0.196;            % 機身高度 (m)
            phantom_config.body_width = 0.289;             % 機身寬度 (m)
            phantom_config.body_length = 0.350;            % 機身長度 (m)
            
            % 慣量矩陣 (kg⋅m²)
            phantom_config.inertia_matrix = [
                0.0347563,  0,          0;
                0,          0.0458929,  0;
                0,          0,          0.0977
            ];
            
            obj.airframe_config('phantom') = phantom_config;
            
            % === FPV穿越機風格配置 ===
            racing_config = struct();
            racing_config.name = 'FPV競速穿越機';
            racing_config.mass = 0.68;                     % 總重量 (kg)
            racing_config.wheelbase = 0.220;               % 軸距 (m)
            racing_config.arm_length = 0.110;              % 臂長 (m) 
            racing_config.body_height = 0.045;             % 機身高度 (m)
            racing_config.body_width = 0.095;              % 機身寬度 (m)
            racing_config.body_length = 0.150;             % 機身長度 (m)
            
            % 慣量矩陣 (kg⋅m²) - 更輕盈，響應更快
            racing_config.inertia_matrix = [
                0.0083,     0,          0;
                0,          0.0083,     0;
                0,          0,          0.0134
            ];
            
            obj.airframe_config('racing') = racing_config;
            
            % === 載重貨運機風格配置 ===
            cargo_config = struct();
            cargo_config.name = '載重貨運無人機';
            cargo_config.mass = 4.2;                       % 總重量 (kg)
            cargo_config.wheelbase = 0.85;                 % 軸距 (m)
            cargo_config.arm_length = 0.425;               % 臂長 (m)
            cargo_config.body_height = 0.25;               % 機身高度 (m) 
            cargo_config.body_width = 0.40;                % 機身寬度 (m)
            cargo_config.body_length = 0.60;               % 機身長度 (m)
            
            % 慣量矩陣 (kg⋅m²) - 較大較穩定
            cargo_config.inertia_matrix = [
                0.162,      0,          0;
                0,          0.162,      0;
                0,          0,          0.295
            ];
            
            obj.airframe_config('cargo') = cargo_config;
            
            % === 標準配置 ===
            standard_config = struct();
            standard_config.name = '標準四旋翼';
            standard_config.mass = 1.5;                    % 總重量 (kg)
            standard_config.wheelbase = 0.58;              % 軸距 (m)
            standard_config.arm_length = 0.29;             % 臂長 (m)
            standard_config.body_height = 0.15;            % 機身高度 (m)
            standard_config.body_width = 0.20;             % 機身寬度 (m)  
            standard_config.body_length = 0.30;            % 機身長度 (m)
            
            % 慣量矩陣 (kg⋅m²)
            standard_config.inertia_matrix = [
                0.029,      0,          0;
                0,          0.029,      0; 
                0,          0,          0.055
            ];
            
            obj.airframe_config('standard') = standard_config;
        end
        
        function load_configuration(obj, config_name)
            % 載入指定配置
            fprintf('📋 載入物理配置：%s\n', config_name);
            
            if ~obj.airframe_config.isKey(config_name)
                fprintf('⚠️ 配置不存在，使用標準配置\n');
                config_name = 'standard';
            end
            
            airframe = obj.airframe_config(config_name);
            
            % === 推進系統配置 ===
            obj.propulsion_system = obj.configure_propulsion_system(config_name);
            
            % === 電池系統配置 ===  
            obj.battery_system = obj.configure_battery_system(config_name);
            
            % === 感測器套件配置 ===
            obj.sensor_suite = obj.configure_sensor_suite(config_name);
            
            % === 空氣動力學配置 ===
            obj.aerodynamics = obj.configure_aerodynamics(config_name, airframe);
            
            % === 環境參數配置 ===
            obj.environment = obj.configure_environment();
            
            fprintf('   ✅ %s 配置已載入\n', airframe.name);
        end
        
        function propulsion = configure_propulsion_system(obj, config_name)
            % 配置推進系統
            propulsion = struct();
            
            switch config_name
                case 'phantom'
                    % DJI Phantom 4 風格推進系統
                    propulsion.motor_type = 'Brushless DC';
                    propulsion.motor_kv = 960;                      % KV值 (RPM/V)
                    propulsion.motor_max_current = 15.0;            % 最大電流 (A)
                    propulsion.motor_resistance = 0.12;             % 電機內阻 (Ω)
                    propulsion.motor_time_constant = 0.025;         % 電機時間常數 (s)
                    propulsion.motor_max_rpm = 8000;                % 最大轉速 (RPM)
                    propulsion.motor_idle_rpm = 1200;               % 怠速轉速 (RPM)
                    
                    % 螺旋槳參數 (9.4×5英吋)
                    propulsion.prop_diameter = 0.2388;             % 直徑 (m)
                    propulsion.prop_pitch = 0.127;                 % 螺距 (m) 
                    propulsion.prop_blade_count = 2;               % 葉片數
                    propulsion.prop_material = 'Carbon Fiber';
                    propulsion.prop_mass = 0.015;                  % 螺旋槳重量 (kg)
                    
                    % 推力和扭矩係數
                    propulsion.thrust_coefficient = 1.05e-5;       % 推力係數
                    propulsion.torque_coefficient = 1.68e-7;       % 扭矩係數
                    propulsion.power_coefficient = 2.1e-7;         % 功率係數
                    
                case 'racing'
                    % FPV競速機推進系統
                    propulsion.motor_type = 'High Performance Brushless';
                    propulsion.motor_kv = 2300;                    % 高KV值適合競速
                    propulsion.motor_max_current = 30.0;           % 高電流輸出
                    propulsion.motor_resistance = 0.08;            % 低內阻
                    propulsion.motor_time_constant = 0.015;        % 快速響應
                    propulsion.motor_max_rpm = 25000;              % 極高轉速
                    propulsion.motor_idle_rpm = 2000;
                    
                    % 螺旋槳參數 (5×4.3英吋三葉槳)
                    propulsion.prop_diameter = 0.127;             % 小直徑高轉速
                    propulsion.prop_pitch = 0.109;
                    propulsion.prop_blade_count = 3;               % 三葉槳更好響應
                    propulsion.prop_material = 'Carbon Fiber Racing';
                    propulsion.prop_mass = 0.005;                 % 輕量化
                    
                    propulsion.thrust_coefficient = 8.2e-6;
                    propulsion.torque_coefficient = 1.1e-7;
                    propulsion.power_coefficient = 1.4e-7;
                    
                case 'cargo'
                    % 載重機推進系統
                    propulsion.motor_type = 'High Torque Brushless';
                    propulsion.motor_kv = 400;                     % 低KV高扭矩
                    propulsion.motor_max_current = 45.0;           % 大電流
                    propulsion.motor_resistance = 0.15;
                    propulsion.motor_time_constant = 0.045;        % 較慢但穩定
                    propulsion.motor_max_rpm = 4500;               % 低轉速高效率
                    propulsion.motor_idle_rpm = 800;
                    
                    % 螺旋槳參數 (15×5.5英吋) 
                    propulsion.prop_diameter = 0.381;             % 大直徑高效率
                    propulsion.prop_pitch = 0.1397;
                    propulsion.prop_blade_count = 2;
                    propulsion.prop_material = 'Carbon Fiber Heavy Duty';
                    propulsion.prop_mass = 0.055;
                    
                    propulsion.thrust_coefficient = 2.8e-5;       % 高推力係數
                    propulsion.torque_coefficient = 4.2e-7;
                    propulsion.power_coefficient = 5.1e-7;
                    
                otherwise % 'standard'
                    propulsion.motor_type = 'Standard Brushless';
                    propulsion.motor_kv = 920;
                    propulsion.motor_max_current = 22.0;
                    propulsion.motor_resistance = 0.10;
                    propulsion.motor_time_constant = 0.02;
                    propulsion.motor_max_rpm = 8000;
                    propulsion.motor_idle_rpm = 1000;
                    
                    propulsion.prop_diameter = 0.254;             % 10英吋
                    propulsion.prop_pitch = 0.114;                % 4.5英吋螺距
                    propulsion.prop_blade_count = 2;
                    propulsion.prop_material = 'Plastic Composite';
                    propulsion.prop_mass = 0.018;
                    
                    propulsion.thrust_coefficient = 8.55e-6;
                    propulsion.torque_coefficient = 1.6e-7;
                    propulsion.power_coefficient = 2.0e-7;
            end
            
            % 計算衍生參數
            obj.calculate_propulsion_derivatives(propulsion);
        end
        
        function calculate_propulsion_derivatives(obj, propulsion)
            % 計算推進系統衍生參數
            
            % 單電機最大推力 (N) - 基於最大轉速
            max_rpm = propulsion.motor_max_rpm;
            prop_area = pi * (propulsion.prop_diameter/2)^2;
            
            propulsion.max_thrust_per_motor = propulsion.thrust_coefficient * ...
                                            (max_rpm/60)^2 * prop_area * 1.225; % 標準大氣密度
            
            % 總最大推力
            propulsion.total_max_thrust = propulsion.max_thrust_per_motor * 4;
            
            % 懸停推力 (假設懸停需要60%最大推力)
            propulsion.hover_thrust_ratio = 0.6;
            propulsion.hover_rpm = max_rpm * sqrt(propulsion.hover_thrust_ratio);
            
            % 推重比計算
            airframe_mass = 1.5; % 預設值，將被實際配置覆蓋
            propulsion.thrust_to_weight_ratio = propulsion.total_max_thrust / (airframe_mass * 9.81);
        end
        
        function battery = configure_battery_system(obj, config_name)
            % 配置電池系統
            battery = struct();
            
            switch config_name
                case 'phantom'
                    battery.type = 'LiPo 4S';
                    battery.cell_count = 4;
                    battery.nominal_voltage = 14.8;               % 標稱電壓 (V)
                    battery.max_voltage = 16.8;                  % 充滿電壓 (V)
                    battery.min_voltage = 12.8;                  % 最低電壓 (V)
                    battery.capacity_mah = 5870;                 % 容量 (mAh)
                    battery.capacity_wh = 86.9;                  % 瓦時 (Wh)
                    battery.max_discharge_rate = 10;             % C數放電倍率
                    battery.internal_resistance = 0.015;         % 內阻 (Ω)
                    battery.mass = 0.365;                        % 電池重量 (kg)
                    
                case 'racing'  
                    battery.type = 'LiPo 6S Racing';
                    battery.cell_count = 6;
                    battery.nominal_voltage = 22.2;
                    battery.max_voltage = 25.2;
                    battery.min_voltage = 19.8;
                    battery.capacity_mah = 1500;                 % 小容量高放電
                    battery.capacity_wh = 33.3;
                    battery.max_discharge_rate = 120;            % 極高放電倍率
                    battery.internal_resistance = 0.008;         % 極低內阻
                    battery.mass = 0.205;
                    
                case 'cargo'
                    battery.type = 'LiPo 12S Heavy Duty';
                    battery.cell_count = 12;
                    battery.nominal_voltage = 44.4;              % 高電壓系統
                    battery.max_voltage = 50.4;
                    battery.min_voltage = 39.6; 
                    battery.capacity_mah = 16000;                % 大容量
                    battery.capacity_wh = 710.4;
                    battery.max_discharge_rate = 25;
                    battery.internal_resistance = 0.025;
                    battery.mass = 2.1;                          % 重型電池
                    
                otherwise % 'standard'
                    battery.type = 'LiPo 6S Standard';
                    battery.cell_count = 6;
                    battery.nominal_voltage = 22.2;
                    battery.max_voltage = 25.2;
                    battery.min_voltage = 19.8;
                    battery.capacity_mah = 5000;
                    battery.capacity_wh = 111.0;
                    battery.max_discharge_rate = 45;
                    battery.internal_resistance = 0.02;
                    battery.mass = 0.685;
            end
            
            % 計算電池衍生參數
            obj.calculate_battery_derivatives(battery);
        end
        
        function calculate_battery_derivatives(obj, battery)
            % 計算電池衍生參數
            
            % 最大連續放電電流
            battery.max_continuous_current = battery.capacity_mah / 1000 * battery.max_discharge_rate;
            
            % 最大連續功率
            battery.max_continuous_power = battery.nominal_voltage * battery.max_continuous_current;
            
            % 能量密度
            battery.energy_density_wh_kg = battery.capacity_wh / battery.mass;
            
            % 功率密度  
            battery.power_density_w_kg = battery.max_continuous_power / battery.mass;
            
            % 電池放電曲線建模（簡化線性模型）
            battery.discharge_curve = struct();
            battery.discharge_curve.voltage_full = battery.max_voltage;
            battery.discharge_curve.voltage_nominal = battery.nominal_voltage; 
            battery.discharge_curve.voltage_empty = battery.min_voltage;
            battery.discharge_curve.capacity_points = [0, 0.2, 0.8, 1.0]; % 充電狀態
            battery.discharge_curve.voltage_points = [battery.max_voltage, ...
                                                    battery.nominal_voltage + 0.8, ...
                                                    battery.nominal_voltage, ...
                                                    battery.min_voltage];
        end
        
        function sensors = configure_sensor_suite(obj, config_name)
            % 配置感測器套件
            sensors = struct();
            
            switch config_name
                case 'phantom'
                    sensors.imu_type = 'High Precision IMU';
                    sensors.gyro_range = 2000;                   % 陀螺儀量程 (°/s)
                    sensors.gyro_noise = 0.01;                   % 陀螺儀噪聲 (°/s)
                    sensors.accel_range = 16;                    % 加速度計量程 (g)
                    sensors.accel_noise = 0.005;                % 加速度計噪聲 (g)
                    
                    sensors.magnetometer_enabled = true;
                    sensors.mag_noise = 0.5;                     % 磁力計噪聲 (mGauss)
                    
                    sensors.barometer_enabled = true;
                    sensors.baro_noise = 0.1;                    % 氣壓計噪聲 (m)
                    
                    sensors.gps_enabled = true;
                    sensors.gps_accuracy = 1.5;                  % GPS精度 (m)
                    
                case 'racing'
                    sensors.imu_type = 'Racing IMU';
                    sensors.gyro_range = 4000;                   % 高量程適應激烈動作
                    sensors.gyro_noise = 0.02;
                    sensors.accel_range = 32;
                    sensors.accel_noise = 0.01;
                    
                    sensors.magnetometer_enabled = false;        % 競速機通常不用磁力計
                    sensors.barometer_enabled = true;
                    sensors.baro_noise = 0.2;
                    sensors.gps_enabled = false;                 % 室內飛行
                    
                case 'cargo'
                    sensors.imu_type = 'Industrial Grade IMU';
                    sensors.gyro_range = 1000;                   % 穩定性優先
                    sensors.gyro_noise = 0.005;                  % 低噪聲
                    sensors.accel_range = 8;
                    sensors.accel_noise = 0.002;
                    
                    sensors.magnetometer_enabled = true;
                    sensors.mag_noise = 0.2;
                    
                    sensors.barometer_enabled = true;
                    sensors.baro_noise = 0.05;                   % 高精度氣壓計
                    
                    sensors.gps_enabled = true;
                    sensors.gps_accuracy = 0.3;                  % RTK級精度
                    
                otherwise % 'standard'
                    sensors.imu_type = 'Standard IMU';
                    sensors.gyro_range = 2000;
                    sensors.gyro_noise = 0.015;
                    sensors.accel_range = 16;
                    sensors.accel_noise = 0.008;
                    
                    sensors.magnetometer_enabled = true;
                    sensors.mag_noise = 1.0;
                    
                    sensors.barometer_enabled = true;
                    sensors.baro_noise = 0.15;
                    
                    sensors.gps_enabled = true;
                    sensors.gps_accuracy = 2.5;
            end
            
            % 感測器更新頻率
            sensors.imu_update_rate = 1000;                      % IMU更新頻率 (Hz)
            sensors.mag_update_rate = 50;                        % 磁力計更新頻率 (Hz)  
            sensors.baro_update_rate = 20;                       % 氣壓計更新頻率 (Hz)
            sensors.gps_update_rate = 10;                        % GPS更新頻率 (Hz)
        end
        
        function aero = configure_aerodynamics(obj, config_name, airframe)
            % 配置空氣動力學參數
            aero = struct();
            
            % 基本空氣動力學參數
            aero.air_density = 1.225;                           % 標準大氣密度 (kg/m³)
            aero.reference_area = airframe.body_width * airframe.body_length; % 參考面積 (m²)
            
            switch config_name
                case 'phantom'
                    % 攝影機型 - 平衡的空氣動力學特性
                    aero.drag_coefficients = [0.12, 0.12, 0.18]; % [Cx, Cy, Cz]
                    aero.angular_drag_coefficients = [0.008, 0.008, 0.012]; % 角阻尼
                    
                case 'racing'
                    % 競速機 - 低阻力設計  
                    aero.drag_coefficients = [0.08, 0.08, 0.15]; % 流線型設計
                    aero.angular_drag_coefficients = [0.005, 0.005, 0.008];
                    
                case 'cargo'
                    % 載重機 - 高阻力但穩定
                    aero.drag_coefficients = [0.18, 0.18, 0.25]; % 較大阻力
                    aero.angular_drag_coefficients = [0.015, 0.015, 0.020];
                    
                otherwise % 'standard'
                    aero.drag_coefficients = [0.10, 0.10, 0.15];
                    aero.angular_drag_coefficients = [0.010, 0.010, 0.015];
            end
            
            % 地面效應參數
            aero.ground_effect_height = 2.0 * max(airframe.body_width, airframe.body_length);
            aero.ground_effect_gain = 1.25;                     % 地面效應增益
            
            % 風場影響參數
            aero.wind_sensitivity = struct();
            aero.wind_sensitivity.translational = 0.8;          % 平移風敏感度
            aero.wind_sensitivity.rotational = 0.3;             % 旋轉風敏感度
        end
        
        function env = configure_environment(obj)
            % 配置環境參數
            env = struct();
            
            % 大氣參數
            env.atmosphere = struct();
            env.atmosphere.pressure = 101325;                   % 標準大氣壓 (Pa)
            env.atmosphere.temperature = 288.15;                % 標準溫度 (K)
            env.atmosphere.humidity = 0.5;                      % 相對濕度
            env.atmosphere.density = 1.225;                     % 空氣密度 (kg/m³)
            
            % 重力參數
            env.gravity = struct();
            env.gravity.magnitude = 9.81;                       % 重力加速度 (m/s²)
            env.gravity.direction = [0, 0, -1];                 % 重力方向向量
            
            % 風場參數  
            env.wind = struct();
            env.wind.enabled = true;
            env.wind.base_velocity = [0, 0, 0];                 % 基礎風速 (m/s)
            env.wind.turbulence_intensity = 0.1;                % 紊流強度
            env.wind.gust_factor = 1.5;                         % 陣風因子
            
            % 溫度對電池性能的影響
            env.temperature_effects = struct();
            env.temperature_effects.enabled = true;
            env.temperature_effects.optimal_temp = 298.15;      % 最佳工作溫度 (K)
            env.temperature_effects.capacity_temp_coeff = -0.005; % 容量溫度係數 (/K)
        end
        
        function validate_physics_parameters(obj)
            % 驗證物理參數的一致性
            fprintf('🔍 驗證物理參數...\n');
            
            % 檢查推重比
            total_mass = obj.get_total_mass();
            max_thrust = obj.propulsion_system.total_max_thrust;
            thrust_to_weight = max_thrust / (total_mass * 9.81);
            
            if thrust_to_weight < 1.5
                fprintf('   ⚠️ 推重比偏低: %.2f (建議 > 1.5)\n', thrust_to_weight);
            elseif thrust_to_weight > 4.0
                fprintf('   ⚠️ 推重比偏高: %.2f (建議 < 4.0)\n', thrust_to_weight);
            else
                fprintf('   ✅ 推重比合理: %.2f\n', thrust_to_weight);
            end
            
            % 檢查電池功率
            max_power_required = obj.estimate_max_power_required();
            battery_max_power = obj.battery_system.max_continuous_power;
            
            if battery_max_power < max_power_required * 1.2 % 20% 餘量
                fprintf('   ⚠️ 電池功率可能不足\n');
            else
                fprintf('   ✅ 電池功率充足\n');
            end
        end
        
        function total_mass = get_total_mass(obj)
            % 計算總質量
            if isempty(obj.airframe_config)
                total_mass = 1.5; % 預設值
                return;
            end
            
            airframe_keys = obj.airframe_config.keys;
            if ~isempty(airframe_keys)
                config = obj.airframe_config(airframe_keys{1});
                total_mass = config.mass + obj.battery_system.mass;
            else
                total_mass = 1.5;
            end
        end
        
        function max_power = estimate_max_power_required(obj)
            % 估算最大功率需求
            % 簡化功率模型：P = T^(3/2) / (prop_efficiency * motor_efficiency)
            
            hover_thrust = obj.get_total_mass() * 9.81; % 懸停推力
            max_thrust = obj.propulsion_system.total_max_thrust;
            
            % 假設效率
            prop_efficiency = 0.8;
            motor_efficiency = 0.85;
            total_efficiency = prop_efficiency * motor_efficiency;
            
            % 功率估算 (簡化模型)
            hover_power = (hover_thrust^1.5) / (total_efficiency * sqrt(2 * obj.environment.atmosphere.density * pi * (obj.propulsion_system.prop_diameter/2)^2));
            max_power = hover_power * 2.0; % 預留100%餘量給機動
        end
        
        function initialize_computation_cache(obj)
            % 初始化計算快取
            obj.computation_cache = struct();
            obj.computation_cache.thrust_curves = containers.Map();
            obj.computation_cache.power_curves = containers.Map();
            obj.computation_cache.efficiency_maps = containers.Map();
        end
        
        function config_list = list_available_configurations(obj)
            % 列出可用配置
            config_keys = obj.airframe_config.keys;
            config_list = cell(length(config_keys), 2);
            
            for i = 1:length(config_keys)
                key = config_keys{i};
                config = obj.airframe_config(key);
                config_list{i, 1} = key;
                config_list{i, 2} = config.name;
            end
        end
        
        function print_configuration_summary(obj)
            % 打印配置摘要
            fprintf('\n=== 無人機物理參數摘要 ===\n');
            
            if ~isempty(obj.airframe_config)
                airframe_keys = obj.airframe_config.keys;
                if ~isempty(airframe_keys)
                    config = obj.airframe_config(airframe_keys{1});
                    fprintf('機架配置: %s\n', config.name);
                    fprintf('   總重量: %.2f kg\n', obj.get_total_mass());
                    fprintf('   軸距: %.0f mm\n', config.wheelbase * 1000);
                    fprintf('   尺寸: %.0f×%.0f×%.0f mm\n', ...
                            config.body_length*1000, config.body_width*1000, config.body_height*1000);
                end
            end
            
            if ~isempty(obj.propulsion_system)
                fprintf('\n推進系統:\n');
                fprintf('   電機類型: %s\n', obj.propulsion_system.motor_type);
                fprintf('   螺旋槳: %.1f" (%.0f葉)\n', ...
                        obj.propulsion_system.prop_diameter*39.37, obj.propulsion_system.prop_blade_count);
                fprintf('   最大推力: %.1f N\n', obj.propulsion_system.total_max_thrust);
                fprintf('   推重比: %.2f\n', obj.propulsion_system.total_max_thrust/(obj.get_total_mass()*9.81));
            end
            
            if ~isempty(obj.battery_system)
                fprintf('\n電池系統:\n'); 
                fprintf('   類型: %s\n', obj.battery_system.type);
                fprintf('   容量: %.0f mAh (%.1f Wh)\n', ...
                        obj.battery_system.capacity_mah, obj.battery_system.capacity_wh);
                fprintf('   最大放電: %.0f A (%.0f C)\n', ...
                        obj.battery_system.max_continuous_current, obj.battery_system.max_discharge_rate);
            end
            
            fprintf('============================\n\n');
        end
    end
end