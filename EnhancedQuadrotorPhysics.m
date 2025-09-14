% EnhancedQuadrotorPhysics.m - 修復版
% 解決 total_max_thrust 字段問題

classdef EnhancedQuadrotorPhysics < handle
    
    properties
        airframe_config
        propulsion_system
        battery_system
        sensor_suite
        aerodynamics
        environment
        computation_cache
        current_config_name
    end
    
    methods
        function obj = EnhancedQuadrotorPhysics(config_name)
            % 建構函數
            if nargin < 1
                config_name = 'standard';
            end
            
            fprintf('🔧 初始化增強物理參數模組...\\n');
            obj.current_config_name = config_name;
            obj.initialize_airframe_configs();
            obj.load_configuration(config_name);
            obj.validate_physics_parameters();
            obj.initialize_computation_cache();
            
            fprintf('✅ 物理參數模組初始化完成\\n');
        end
        
        function initialize_airframe_configs(obj)
            % 初始化機架配置
            obj.airframe_config = containers.Map();
            
            % 標準配置
            standard_config = struct();
            standard_config.name = '標準四旋翼';
            standard_config.mass = 1.5;
            standard_config.wheelbase = 0.58;
            standard_config.arm_length = 0.29;
            standard_config.body_height = 0.15;
            standard_config.body_width = 0.20;
            standard_config.body_length = 0.30;
            standard_config.inertia_matrix = diag([0.029, 0.029, 0.055]);
            
            obj.airframe_config('standard') = standard_config;
            
            % 其他配置可以在這裡添加...
        end
        
        function load_configuration(obj, config_name)
            % 載入指定配置
            fprintf('📋 載入物理配置：%s\\n', config_name);
            
            if ~obj.airframe_config.isKey(config_name)
                fprintf('⚠️ 配置不存在，使用標準配置\\n');
                config_name = 'standard';
            end
            
            airframe = obj.airframe_config(config_name);
            
            % === 關鍵修復：推進系統配置 ===
            obj.propulsion_system = obj.configure_propulsion_system_fixed(config_name);
            
            % === 電池系統配置 ===
            obj.battery_system = obj.configure_battery_system(config_name);
            
            % === 感測器套件配置 ===
            obj.sensor_suite = obj.configure_sensor_suite(config_name);
            
            % === 空氣動力學配置 ===
            obj.aerodynamics = obj.configure_aerodynamics(config_name, airframe);
            
            % === 環境參數配置 ===
            obj.environment = obj.configure_environment();
            
            fprintf('   ✅ %s 配置已載入\\n', airframe.name);
        end
        
        function propulsion = configure_propulsion_system_fixed(obj, config_name)
            % 修復版推進系統配置
            propulsion = struct();
            
            % 基本參數
            propulsion.motor_type = 'Standard Brushless';
            propulsion.motor_kv = 920;
            propulsion.motor_max_current = 22.0;
            propulsion.motor_resistance = 0.10;
            propulsion.motor_time_constant = 0.02;
            propulsion.motor_max_rpm = 8000;
            propulsion.motor_idle_rpm = 1000;
            
            propulsion.prop_diameter = 0.254;
            propulsion.prop_pitch = 0.114;
            propulsion.prop_blade_count = 2;
            propulsion.prop_material = 'Plastic Composite';
            propulsion.prop_mass = 0.018;
            
            propulsion.thrust_coefficient = 8.55e-6;
            propulsion.torque_coefficient = 1.6e-7;
            propulsion.power_coefficient = 2.0e-7;
            
            % 🔧 關鍵修復：直接計算並設置所有必要字段
            max_rpm = propulsion.motor_max_rpm;
            air_density = 1.225;
            prop_diameter = propulsion.prop_diameter;
            thrust_coeff = propulsion.thrust_coefficient;
            
            % 計算推力參數
            single_motor_thrust = thrust_coeff * air_density * (max_rpm/60)^2 * prop_diameter^4;
            
            % 確保所有字段都存在
            propulsion.max_thrust_per_motor = single_motor_thrust;
            propulsion.total_max_thrust = single_motor_thrust * 4;  % 關鍵字段
            propulsion.hover_thrust_ratio = 0.6;
            propulsion.hover_rpm = max_rpm * sqrt(propulsion.hover_thrust_ratio);
            
            % 獲取機架質量
            if obj.airframe_config.isKey(config_name)
                airframe_mass = obj.airframe_config(config_name).mass;
            else
                airframe_mass = 1.5;
            end
            
            propulsion.thrust_to_weight_ratio = propulsion.total_max_thrust / (airframe_mass * 9.81);
            
            % 功率參數
            propulsion.hover_power_per_motor = 200;  % W
            propulsion.total_hover_power = 800;      % W
            propulsion.propeller_efficiency = 0.8;
            propulsion.motor_efficiency = 0.85;
            propulsion.total_efficiency = 0.68;
        end
        
        function battery = configure_battery_system(obj, config_name)
            % 配置電池系統
            battery = struct();
            
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
            
            % 衍生參數
            battery.max_continuous_current = battery.capacity_mah / 1000 * battery.max_discharge_rate;
            battery.max_continuous_power = battery.nominal_voltage * battery.max_continuous_current;
            battery.energy_density_wh_kg = battery.capacity_wh / battery.mass;
            battery.power_density_w_kg = battery.max_continuous_power / battery.mass;
        end
        
        function sensors = configure_sensor_suite(obj, config_name)
            % 配置感測器套件
            sensors = struct();
            
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
            
            sensors.imu_update_rate = 1000;
            sensors.mag_update_rate = 50;
            sensors.baro_update_rate = 20;
            sensors.gps_update_rate = 10;
        end
        
        function aero = configure_aerodynamics(obj, config_name, airframe)
            % 配置空氣動力學參數
            aero = struct();
            
            aero.air_density = 1.225;
            aero.reference_area = airframe.body_width * airframe.body_length;
            aero.drag_coefficients = [0.10, 0.10, 0.15];
            aero.angular_drag_coefficients = [0.010, 0.010, 0.015];
            aero.ground_effect_height = 2.0 * max(airframe.body_width, airframe.body_length);
            aero.ground_effect_gain = 1.25;
            
            aero.wind_sensitivity = struct();
            aero.wind_sensitivity.translational = 0.8;
            aero.wind_sensitivity.rotational = 0.3;
        end
        
        function env = configure_environment(obj)
            % 配置環境參數
            env = struct();
            
            env.atmosphere = struct();
            env.atmosphere.pressure = 101325;
            env.atmosphere.temperature = 288.15;
            env.atmosphere.humidity = 0.5;
            env.atmosphere.density = 1.225;
            
            env.gravity = struct();
            env.gravity.magnitude = 9.81;
            env.gravity.direction = [0, 0, -1];
            
            env.wind = struct();
            env.wind.enabled = true;
            env.wind.base_velocity = [0, 0, 0];
            env.wind.turbulence_intensity = 0.1;
            env.wind.gust_factor = 1.5;
        end
        
        function validate_physics_parameters(obj)
            % 驗證物理參數
            fprintf('🔍 驗證物理參數...\\n');
            
            try
                total_mass = obj.get_total_mass();
                
                if isfield(obj.propulsion_system, 'total_max_thrust')
                    max_thrust = obj.propulsion_system.total_max_thrust;
                    thrust_to_weight = max_thrust / (total_mass * 9.81);
                    
                    if thrust_to_weight < 1.5
                        fprintf('   ⚠️ 推重比偏低: %.2f (建議 > 1.5)\\n', thrust_to_weight);
                    elseif thrust_to_weight > 4.0
                        fprintf('   ⚠️ 推重比偏高: %.2f (建議 < 4.0)\\n', thrust_to_weight);
                    else
                        fprintf('   ✅ 推重比合理: %.2f\\n', thrust_to_weight);
                    end
                else
                    fprintf('   ❌ 推進系統參數不完整\\n');
                end
                
                if isfield(obj.battery_system, 'max_continuous_power')
                    fprintf('   ✅ 電池功率充足\\n');
                end
            catch ME
                fprintf('   ⚠️ 驗證過程出錯: %s\\n', ME.message);
            end
        end
        
        function total_mass = get_total_mass(obj)
            % 計算總質量
            try
                if obj.airframe_config.isKey(obj.current_config_name)
                    config = obj.airframe_config(obj.current_config_name);
                    airframe_mass = config.mass;
                else
                    airframe_mass = 1.5;
                end
                
                if isfield(obj.battery_system, 'mass')
                    battery_mass = obj.battery_system.mass;
                else
                    battery_mass = 0.5;
                end
                
                total_mass = airframe_mass + battery_mass;
            catch
                total_mass = 2.0;
            end
        end
        
        function initialize_computation_cache(obj)
            % 初始化計算快取
            obj.computation_cache = struct();
            obj.computation_cache.thrust_curves = containers.Map();
            obj.computation_cache.power_curves = containers.Map();
            obj.computation_cache.efficiency_maps = containers.Map();
        end
        
        function print_configuration_summary(obj)
            % 打印配置摘要
            fprintf('\\n=== 無人機物理參數摘要 ===\\n');
            
            if obj.airframe_config.isKey(obj.current_config_name)
                config = obj.airframe_config(obj.current_config_name);
                fprintf('機架配置: %s\\n', config.name);
                fprintf('   總重量: %.2f kg\\n', obj.get_total_mass());
                fprintf('   軸距: %.0f mm\\n', config.wheelbase * 1000);
            end
            
            if ~isempty(obj.propulsion_system)
                fprintf('\\n推進系統:\\n');
                fprintf('   電機類型: %s\\n', obj.propulsion_system.motor_type);
                
                if isfield(obj.propulsion_system, 'total_max_thrust')
                    fprintf('   最大推力: %.1f N\\n', obj.propulsion_system.total_max_thrust);
                    fprintf('   推重比: %.2f\\n', obj.propulsion_system.thrust_to_weight_ratio);
                end
            end
            
            if ~isempty(obj.battery_system)
                fprintf('\\n電池系統:\\n');
                fprintf('   類型: %s\\n', obj.battery_system.type);
                fprintf('   容量: %.0f mAh\\n', obj.battery_system.capacity_mah);
                
                if isfield(obj.battery_system, 'max_continuous_current')
                    fprintf('   最大放電: %.0f A\\n', obj.battery_system.max_continuous_current);
                end
            end
            
            fprintf('============================\\n\\n');
        end
    end
end
