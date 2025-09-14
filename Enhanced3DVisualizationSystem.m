% Enhanced3DVisualizationSystem.m
% 增強3D視覺化系統 - 真實無人機模型顯示

classdef Enhanced3DVisualizationSystem < VisualizationSystem
    
    properties
        % 3D模型資源
        drone_models           % 預載的3D無人機模型
        model_cache           % 模型快取
        
        % 渲染設置
        render_quality        % 渲染品質設置
        animation_settings    % 動畫設置
        lighting_system       % 光照系統
        
        % 效果系統
        particle_systems      % 粒子效果系統 (螺旋槳風流等)
        trail_systems         % 軌跡尾巴系統
        
        % 性能優化
        lod_system           % LOD (Level of Detail) 系統
        culling_system       % 視椎體剔除系統
        batch_renderer       % 批次渲染器
        
        % 互動功能
        selection_system     % 選擇系統
        info_panels          % 信息面板
    end
    
    methods
        function obj = Enhanced3DVisualizationSystem(simulator)
            % 建構函數
            obj@VisualizationSystem(simulator);
            
            fprintf('🎨 初始化增強3D視覺化系統...\n');
            
            obj.initialize_3d_models();
            obj.setup_rendering_pipeline();
            obj.initialize_effect_systems();
            obj.setup_performance_optimization();
            obj.initialize_interaction_systems();
            
            fprintf('✅ 增強3D視覺化系統初始化完成\n');
        end
        
        function initialize_3d_models(obj)
            % 初始化3D無人機模型
            fprintf('   📐 創建3D無人機模型...\n');
            
            obj.drone_models = containers.Map();
            obj.model_cache = containers.Map();
            
            % === DJI Phantom風格模型 ===
            obj.create_phantom_model();
            
            % === FPV競速機模型 ===
            obj.create_racing_drone_model();
            
            % === 載重機模型 ===
            obj.create_cargo_drone_model();
            
            % === 標準四旋翼模型 ===
            obj.create_standard_quadrotor_model();
            
            % === 簡化圖標模型 ===
            obj.create_icon_models();
        end
        
        function create_phantom_model(obj)
            % 創建DJI Phantom風格3D模型
            model = struct();
            model.name = 'Phantom';
            model.type = 'detailed';
            
            % 機身 (橢圓體)
            [x_body, y_body, z_body] = ellipsoid(0, 0, 0, 0.175, 0.145, 0.098);
            model.body.vertices = [x_body(:), y_body(:), z_body(:)];
            model.body.faces = obj.generate_ellipsoid_faces(size(x_body, 1), size(x_body, 2));
            model.body.color = [0.9, 0.9, 0.9]; % 白色機身
            model.body.material = 'plastic';
            
            % 4個機臂 (圓柱體)
            arm_length = 0.175;
            arm_radius = 0.012;
            arm_positions = [
                [ arm_length*cosd(45),  arm_length*sind(45), 0];  % 右前臂
                [-arm_length*cosd(45),  arm_length*sind(45), 0];  % 左前臂
                [-arm_length*cosd(45), -arm_length*sind(45), 0];  % 左後臂  
                [ arm_length*cosd(45), -arm_length*sind(45), 0];  % 右後臂
            ];
            
            model.arms = cell(4, 1);
            for i = 1:4
                % 計算機臂方向
                arm_dir = arm_positions(i, :) / norm(arm_positions(i, :));
                
                % 創建圓柱體機臂
                [x_arm, y_arm, z_arm] = obj.create_cylinder([0, 0, 0], arm_positions(i, :), arm_radius, 16);
                
                model.arms{i} = struct();
                model.arms{i}.vertices = [x_arm(:), y_arm(:), z_arm(:)];
                model.arms{i}.faces = obj.generate_cylinder_faces(size(x_arm, 1), size(x_arm, 2));
                model.arms{i}.color = [0.3, 0.3, 0.3]; % 深灰色機臂
                model.arms{i}.position = arm_positions(i, :);
            end
            
            % 4個電機 (圓柱體)
            model.motors = cell(4, 1);
            motor_radius = 0.025;
            motor_height = 0.035;
            
            for i = 1:4
                motor_pos = arm_positions(i, :);
                
                [x_motor, y_motor, z_motor] = cylinder(motor_radius, 16);
                z_motor = z_motor * motor_height - motor_height/2;
                
                % 平移到電機位置
                x_motor = x_motor + motor_pos(1);
                y_motor = y_motor + motor_pos(2); 
                z_motor = z_motor + motor_pos(3);
                
                model.motors{i} = struct();
                model.motors{i}.vertices = [x_motor(:), y_motor(:), z_motor(:)];
                model.motors{i}.faces = obj.generate_cylinder_faces(size(x_motor, 1), size(x_motor, 2));
                model.motors{i}.color = [0.2, 0.2, 0.2]; % 黑色電機
            end
            
            % 4個螺旋槳
            model.propellers = cell(4, 1);
            prop_radius = 0.12; % 9.4英吋螺旋槳
            
            for i = 1:4
                prop_pos = arm_positions(i, :) + [0, 0, motor_height/2];
                model.propellers{i} = obj.create_propeller_model(prop_pos, prop_radius, 2);
                model.propellers{i}.rotation_direction = (-1)^(i+1); % 交替旋轉方向
            end
            
            % 雲台和攝影機 (簡化)
            [x_gimbal, y_gimbal, z_gimbal] = sphere(8);
            x_gimbal = x_gimbal * 0.03;
            y_gimbal = y_gimbal * 0.03; 
            z_gimbal = z_gimbal * 0.03 - 0.12; % 機身下方
            
            model.gimbal = struct();
            model.gimbal.vertices = [x_gimbal(:), y_gimbal(:), z_gimbal(:)];
            model.gimbal.faces = obj.generate_sphere_faces(size(x_gimbal, 1));
            model.gimbal.color = [0.1, 0.1, 0.1]; % 黑色雲台
            
            % 著陸腳架
            model.landing_gear = obj.create_landing_gear('phantom');
            
            obj.drone_models('phantom') = model;
        end
        
        function create_racing_drone_model(obj)
            % 創建FPV競速機3D模型  
            model = struct();
            model.name = 'Racing';
            model.type = 'detailed';
            
            % 機身 (扁平矩形)
            body_length = 0.15;
            body_width = 0.095;
            body_height = 0.045;
            
            % 創建扁平機身
            model.body = obj.create_box_model([0, 0, 0], body_length, body_width, body_height);
            model.body.color = [1.0, 0.3, 0.0]; % 橙色賽車機身
            model.body.material = 'carbon_fiber';
            
            % 4個機臂 (較細的碳纖維臂)
            arm_length = 0.11;
            arm_radius = 0.008;
            arm_positions = [
                [ arm_length*cosd(45),  arm_length*sind(45), 0];
                [-arm_length*cosd(45),  arm_length*sind(45), 0];
                [-arm_length*cosd(45), -arm_length*sind(45), 0];
                [ arm_length*cosd(45), -arm_length*sind(45), 0];
            ];
            
            model.arms = cell(4, 1);
            for i = 1:4
                [x_arm, y_arm, z_arm] = obj.create_cylinder([0, 0, 0], arm_positions(i, :), arm_radius, 8);
                
                model.arms{i} = struct();
                model.arms{i}.vertices = [x_arm(:), y_arm(:), z_arm(:)];
                model.arms{i}.faces = obj.generate_cylinder_faces(size(x_arm, 1), size(x_arm, 2));
                model.arms{i}.color = [0.1, 0.1, 0.1]; % 碳纖維黑
            end
            
            % 高性能電機 (較小)
            model.motors = cell(4, 1);
            motor_radius = 0.018;
            motor_height = 0.025;
            
            for i = 1:4
                motor_pos = arm_positions(i, :);
                model.motors{i} = obj.create_cylinder_model(motor_pos, motor_radius, motor_height);
                model.motors{i}.color = [0.8, 0.1, 0.1]; % 紅色競速電機
            end
            
            % 三葉螺旋槳 (較小)
            prop_radius = 0.063; % 5英吋螺旋槳
            for i = 1:4
                prop_pos = arm_positions(i, :) + [0, 0, motor_height/2];
                model.propellers{i} = obj.create_propeller_model(prop_pos, prop_radius, 3); % 三葉槳
                model.propellers{i}.rotation_direction = (-1)^(i+1);
                model.propellers{i}.color = [0.2, 0.8, 0.2]; % 綠色競速槳
            end
            
            % FPV攝影機
            camera_pos = [body_length/2 - 0.02, 0, body_height/2];
            model.camera = obj.create_box_model(camera_pos, 0.02, 0.02, 0.02);
            model.camera.color = [0.0, 0.0, 0.0]; % 黑色攝影機
            
            % LED燈條 (裝飾)
            model.leds = obj.create_led_strips('racing');
            
            obj.drone_models('racing') = model;
        end
        
        function create_cargo_drone_model(obj)
            % 創建載重機3D模型
            model = struct();
            model.name = 'Cargo';
            model.type = 'detailed';
            
            % 較大的機身
            body_length = 0.60;
            body_width = 0.40;
            body_height = 0.25;
            
            model.body = obj.create_box_model([0, 0, 0], body_length, body_width, body_height);
            model.body.color = [0.4, 0.4, 0.8]; % 藍色工業機身
            model.body.material = 'aluminum';
            
            % 粗壯機臂
            arm_length = 0.425;
            arm_radius = 0.025;
            arm_positions = [
                [ arm_length*cosd(45),  arm_length*sind(45), 0];
                [-arm_length*cosd(45),  arm_length*sind(45), 0];
                [-arm_length*cosd(45), -arm_length*sind(45), 0];
                [ arm_length*cosd(45), -arm_length*sind(45), 0];
            ];
            
            model.arms = cell(4, 1);
            for i = 1:4
                [x_arm, y_arm, z_arm] = obj.create_cylinder([0, 0, 0], arm_positions(i, :), arm_radius, 12);
                
                model.arms{i} = struct();
                model.arms{i}.vertices = [x_arm(:), y_arm(:), z_arm(:)];
                model.arms{i}.faces = obj.generate_cylinder_faces(size(x_arm, 1), size(x_arm, 2));
                model.arms{i}.color = [0.6, 0.6, 0.6]; % 鋁合金色
            end
            
            % 大功率電機
            model.motors = cell(4, 1);
            motor_radius = 0.045;
            motor_height = 0.06;
            
            for i = 1:4
                motor_pos = arm_positions(i, :);
                model.motors{i} = obj.create_cylinder_model(motor_pos, motor_radius, motor_height);
                model.motors{i}.color = [0.3, 0.3, 0.3]; % 重型電機色
            end
            
            % 大直徑螺旋槳
            prop_radius = 0.19; % 15英吋螺旋槳
            for i = 1:4
                prop_pos = arm_positions(i, :) + [0, 0, motor_height/2];
                model.propellers{i} = obj.create_propeller_model(prop_pos, prop_radius, 2);
                model.propellers{i}.rotation_direction = (-1)^(i+1);
                model.propellers{i}.color = [0.2, 0.2, 0.2]; # 黑色重型槳
            end
            
            % 貨物吊掛系統
            cargo_hook_pos = [0, 0, -body_height/2 - 0.05];
            model.cargo_hook = obj.create_sphere_model(cargo_hook_pos, 0.02);
            model.cargo_hook.color = [0.8, 0.8, 0.0]; % 金色掛鉤
            
            % 著陸腳架 (加強版)
            model.landing_gear = obj.create_landing_gear('cargo');
            
            obj.drone_models('cargo') = model;
        end
        
        function create_standard_quadrotor_model(obj)
            % 創建標準四旋翼3D模型
            model = struct();
            model.name = 'Standard';
            model.type = 'detailed';
            
            % 標準機身
            [x_body, y_body, z_body] = ellipsoid(0, 0, 0, 0.15, 0.10, 0.075);
            model.body.vertices = [x_body(:), y_body(:), z_body(:)];
            model.body.faces = obj.generate_ellipsoid_faces(size(x_body, 1), size(x_body, 2));
            model.body.color = [0.2, 0.6, 0.8]; % 藍色機身
            
            % 機臂配置
            arm_length = 0.29;
            arm_radius = 0.015;
            arm_positions = [
                [ arm_length*cosd(45),  arm_length*sind(45), 0];
                [-arm_length*cosd(45),  arm_length*sind(45), 0];
                [-arm_length*cosd(45), -arm_length*sind(45), 0];
                [ arm_length*cosd(45), -arm_length*sind(45), 0];
            ];
            
            model.arms = cell(4, 1);
            model.motors = cell(4, 1);
            model.propellers = cell(4, 1);
            
            for i = 1:4
                % 機臂
                [x_arm, y_arm, z_arm] = obj.create_cylinder([0, 0, 0], arm_positions(i, :), arm_radius, 10);
                model.arms{i} = struct();
                model.arms{i}.vertices = [x_arm(:), y_arm(:), z_arm(:)];
                model.arms{i}.faces = obj.generate_cylinder_faces(size(x_arm, 1), size(x_arm, 2));
                model.arms{i}.color = [0.4, 0.4, 0.4];
                
                % 電機
                motor_pos = arm_positions(i, :);
                model.motors{i} = obj.create_cylinder_model(motor_pos, 0.02, 0.03);
                model.motors{i}.color = [0.2, 0.2, 0.2];
                
                % 螺旋槳 (10英吋)
                prop_pos = arm_positions(i, :) + [0, 0, 0.015];
                model.propellers{i} = obj.create_propeller_model(prop_pos, 0.127, 2);
                model.propellers{i}.rotation_direction = (-1)^(i+1);
            end
            
            obj.drone_models('standard') = model;
        end
        
        function create_icon_models(obj)
            % 創建簡化圖標模型 (遠距離顯示)
            
            % 簡化四旋翼圖標
            icon_model = struct();
            icon_model.name = 'Simple Icon';
            icon_model.type = 'icon';
            
            % 中心點
            icon_model.center = obj.create_sphere_model([0, 0, 0], 0.02);
            icon_model.center.color = [1, 1, 0]; % 黃色中心
            
            % 四個機臂 (簡化為線段)
            arm_length = 0.05;
            icon_model.arms = cell(4, 1);
            
            for i = 1:4
                angle = (i-1) * 90;
                arm_end = arm_length * [cosd(angle), sind(angle), 0];
                
                % 創建細線機臂
                [x_arm, y_arm, z_arm] = obj.create_cylinder([0, 0, 0], arm_end, 0.003, 4);
                icon_model.arms{i} = struct();
                icon_model.arms{i}.vertices = [x_arm(:), y_arm(:), z_arm(:)];
                icon_model.arms{i}.faces = obj.generate_cylinder_faces(size(x_arm, 1), size(x_arm, 2));
                icon_model.arms{i}.color = [0.8, 0.8, 0.8];
            end
            
            obj.drone_models('icon') = icon_model;
        end
        
        function setup_rendering_pipeline(obj)
            % 設置渲染管線
            fprintf('   🎬 設置渲染管線...\n');
            
            obj.render_quality = struct();
            obj.render_quality.level = 'high'; % low, medium, high, ultra
            obj.render_quality.shadows_enabled = true;
            obj.render_quality.reflections_enabled = true;
            obj.render_quality.anti_aliasing = 4; % MSAA等級
            
            obj.animation_settings = struct();
            obj.animation_settings.propeller_rotation = true;
            obj.animation_settings.smooth_interpolation = true;
            obj.animation_settings.frame_rate = 30; % FPS
            
            % 光照系統
            obj.setup_lighting_system();
        end
        
        function setup_lighting_system(obj)
            % 設置光照系統
            obj.lighting_system = struct();
            
            % 主光源 (太陽光)
            obj.lighting_system.sun_light = struct();
            obj.lighting_system.sun_light.direction = [-0.5, -0.3, -1];
            obj.lighting_system.sun_light.color = [1.0, 0.95, 0.8];
            obj.lighting_system.sun_light.intensity = 0.8;
            
            % 環境光
            obj.lighting_system.ambient_light = struct();
            obj.lighting_system.ambient_light.color = [0.4, 0.5, 0.6];
            obj.lighting_system.ambient_light.intensity = 0.3;
            
            % 動態光源 (LED燈效)
            obj.lighting_system.dynamic_lights = containers.Map();
        end
        
        function initialize_effect_systems(obj)
            % 初始化效果系統
            fprintf('   ✨ 初始化視覺效果系統...\n');
            
            % 粒子系統 (螺旋槳下洗流等)
            obj.particle_systems = containers.Map();
            obj.initialize_propwash_effects();
            
            % 軌跡尾巴系統
            obj.trail_systems = containers.Map();
            obj.initialize_trail_effects();
        end
        
        function initialize_propwash_effects(obj)
            % 初始化螺旋槳下洗流效果
            propwash_effect = struct();
            propwash_effect.enabled = true;
            propwash_effect.particle_count = 50;
            propwash_effect.particle_lifetime = 2.0; % 秒
            propwash_effect.velocity_scale = 5.0;
            propwash_effect.alpha_decay = 0.8;
            
            obj.particle_systems('propwash') = propwash_effect;
        end
        
        function initialize_trail_effects(obj)
            % 初始化軌跡尾巴效果
            trail_effect = struct();
            trail_effect.enabled = true;
            trail_effect.max_points = 100;
            trail_effect.fade_time = 10.0; % 秒
            trail_effect.width = 0.5; % 米
            trail_effect.color_start = [1, 1, 0, 1]; % RGBA
            trail_effect.color_end = [1, 1, 0, 0]; % 透明
            
            obj.trail_systems('default') = trail_effect;
        end
        
        function setup_performance_optimization(obj)
            % 設置性能優化
            fprintf('   ⚡ 設置性能優化系統...\n');
            
            % LOD系統
            obj.lod_system = struct();
            obj.lod_system.enabled = true;
            obj.lod_system.distances = [50, 100, 200]; % 米
            obj.lod_system.models = {'detailed', 'simplified', 'icon'};
            
            % 視椎體剔除
            obj.culling_system = struct();
            obj.culling_system.enabled = true;
            obj.culling_system.frustum_margin = 10; % 額外邊界 (米)
            
            % 批次渲染
            obj.batch_renderer = struct();
            obj.batch_renderer.enabled = true;
            obj.batch_renderer.max_batch_size = 50;
        end
        
        function initialize_interaction_systems(obj)
            % 初始化互動系統
            fprintf('   🖱️ 初始化互動系統...\n');
            
            obj.selection_system = struct();
            obj.selection_system.enabled = true;
            obj.selection_system.selected_drone = '';
            obj.selection_system.highlight_color = [1, 0.5, 0]; % 橙色高亮
            
            obj.info_panels = containers.Map();
        end
        
        % === 重寫父類的繪圖方法 ===
        
        function plot_drone_icon(obj, position, drone_id)
            % 重寫：使用3D模型替代星星圖標
            
            if ~obj.is_valid_position(position)
                return;
            end
            
            % 決定使用的模型類型
            model_type = obj.determine_model_type(drone_id, position);
            
            % 獲取攝影機距離以決定LOD等級
            camera_distance = obj.calculate_camera_distance(position);
            lod_level = obj.determine_lod_level(camera_distance);
            
            % 繪製3D無人機模型
            obj.render_drone_model(position, drone_id, model_type, lod_level);
            
            % 添加視覺效果
            if obj.render_quality.level ~= "low"
                obj.render_visual_effects(position, drone_id);
            end
            
            % 繪製信息標籤
            obj.render_info_label(position, drone_id);
        end
        
        function model_type = determine_model_type(obj, drone_id, position)
            % 決定使用的模型類型
            
            % 檢查是否有自定義模型配置
            if obj.simulator.drones.isKey(drone_id)
                drone_data = obj.simulator.drones(drone_id);
                if isfield(drone_data, 'model_type') && ~isempty(drone_data.model_type)
                    model_type = drone_data.model_type;
                    return;
                end
            end
            
            % 預設使用標準模型
            model_type = 'standard';
        end
        
        function distance = calculate_camera_distance(obj, position)
            % 計算到攝影機的距離
            
            try
                camera_pos = get(obj.plot_axes, 'CameraPosition');
                drone_pos = [position.x, position.y, position.z];
                distance = norm(camera_pos - drone_pos);
            catch
                distance = 100; % 預設距離
            end
        end
        
        function lod_level = determine_lod_level(obj, camera_distance)
            % 決定LOD等級
            
            if ~obj.lod_system.enabled
                lod_level = 'detailed';
                return;
            end
            
            distances = obj.lod_system.distances;
            models = obj.lod_system.models;
            
            if camera_distance < distances(1)
                lod_level = models{1}; % 'detailed'
            elseif camera_distance < distances(2)
                lod_level = models{2}; % 'simplified'
            else
                lod_level = models{3}; % 'icon'
            end
        end
        
        function render_drone_model(obj, position, drone_id, model_type, lod_level)
            % 渲染3D無人機模型
            
            % 獲取模型數據
            if ~obj.drone_models.isKey(model_type)
                model_type = 'standard'; % 備用模型
            end
            
            model = obj.drone_models(model_type);
            
            % 根據LOD等級調整渲染細節
            switch lod_level
                case 'detailed'
                    obj.render_detailed_model(position, drone_id, model);
                case 'simplified'
                    obj.render_simplified_model(position, drone_id, model);
                case 'icon'
                    obj.render_icon_model(position, drone_id);
            end
        end
        
        function render_detailed_model(obj, position, drone_id, model)
            % 渲染詳細模型
            
            pos = [position.x, position.y, position.z];
            
            % 獲取無人機姿態 (如果可用)
            attitude = obj.get_drone_attitude(drone_id);
            
            % 渲染機身
            obj.render_model_component(model.body, pos, attitude);
            
            % 渲染機臂
            if isfield(model, 'arms')
                for i = 1:length(model.arms)
                    obj.render_model_component(model.arms{i}, pos, attitude);
                end
            end
            
            % 渲染電機
            if isfield(model, 'motors')
                for i = 1:length(model.motors)
                    obj.render_model_component(model.motors{i}, pos, attitude);
                end
            end
            
            % 渲染螺旋槳 (帶動畫)
            if isfield(model, 'propellers') && obj.animation_settings.propeller_rotation
                obj.render_rotating_propellers(model.propellers, pos, attitude, drone_id);
            end
            
            % 渲染其他組件
            obj.render_additional_components(model, pos, attitude);
        end
        
        function render_simplified_model(obj, position, drone_id, model)
            % 渲染簡化模型 (減少多邊形數量)
            
            pos = [position.x, position.y, position.z];
            attitude = obj.get_drone_attitude(drone_id);
            
            % 只渲染主要組件
            obj.render_model_component(model.body, pos, attitude);
            
            % 簡化的機臂顯示
            if isfield(model, 'arms')
                for i = 1:2:length(model.arms) % 只顯示一半機臂
                    obj.render_model_component(model.arms{i}, pos, attitude);
                end
            end
        end
        
        function render_icon_model(obj, position, drone_id)
            % 渲染圖標模型
            
            if obj.drone_models.isKey('icon')
                icon_model = obj.drone_models('icon');
                pos = [position.x, position.y, position.z];
                attitude = [0, 0, 0]; % 簡化，無姿態
                
                % 渲染簡化圖標
                obj.render_model_component(icon_model.center, pos, attitude);
                
                if isfield(icon_model, 'arms')
                    for i = 1:length(icon_model.arms)
                        obj.render_model_component(icon_model.arms{i}, pos, attitude);
                    end
                end
            else
                % 回退到原始星星圖標
                plot3(obj.plot_axes, position.x, position.y, position.z, ...
                      'p', 'MarkerSize', 12, 'MarkerFaceColor', 'yellow', ...
                      'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
            end
        end
        
        function render_model_component(obj, component, position, attitude)
            % 渲染模型組件
            
            if ~isfield(component, 'vertices') || ~isfield(component, 'faces')
                return;
            end
            
            % 應用姿態變換
            transformed_vertices = obj.apply_attitude_transform(component.vertices, attitude);
            
            % 應用位置平移
            transformed_vertices = transformed_vertices + repmat(position, size(transformed_vertices, 1), 1);
            
            % 渲染三角面
            try
                patch(obj.plot_axes, ...
                      'Vertices', transformed_vertices, ...
                      'Faces', component.faces, ...
                      'FaceColor', component.color, ...
                      'EdgeColor', 'none', ...
                      'FaceLighting', 'gouraud', ...
                      'AmbientStrength', 0.3, ...
                      'DiffuseStrength', 0.7);
            catch ME
                % 降級處理
                fprintf('模型渲染警告：%s\n', ME.message);
                obj.render_fallback_representation(position);
            end
        end
        
        function render_visual_effects(obj, position, drone_id)
            % 渲染視覺效果
            
            % 螺旋槳下洗流效果
            if obj.particle_systems.isKey('propwash') && obj.particle_systems('propwash').enabled
                obj.render_propwash_effect(position, drone_id);
            end
            
            % 軌跡尾巴效果
            if obj.trail_systems.isKey('default') && obj.trail_systems('default').enabled
                obj.render_trail_effect(position, drone_id);
            end
            
            % 狀態指示燈效果
            obj.render_status_lights(position, drone_id);
        end
        
        function render_info_label(obj, position, drone_id)
            % 渲染信息標籤
            
            % 基本標籤
            label_pos = [position.x, position.y, position.z + 4];
            
            % 獲取無人機狀態信息
            status_info = obj.get_drone_status_info(drone_id);
            
            text(obj.plot_axes, label_pos(1), label_pos(2), label_pos(3), ...
                 sprintf('%s\n%s', drone_id, status_info), ...
                 'Color', 'white', 'FontSize', 9, 'FontWeight', 'bold', ...
                 'HorizontalAlignment', 'center', ...
                 'BackgroundColor', 'black', 'EdgeColor', 'cyan', ...
                 'Margin', 2);
        end
        
        % === 輔助方法 ===
        
        function attitude = get_drone_attitude(obj, drone_id)
            % 獲取無人機姿態 (歐拉角)
            attitude = [0, 0, 0]; % 預設姿態
            
            try
                if obj.simulator.drones.isKey(drone_id)
                    drone_data = obj.simulator.drones(drone_id);
                    current_time = obj.simulator.current_time;
                    
                    % 從軌跡數據中插值姿態 (如果可用)
                    if isfield(drone_data, 'trajectory') && ~isempty(drone_data.trajectory)
                        % 這裡可以實現姿態插值邏輯
                        % attitude = interpolate_attitude(drone_data.trajectory, current_time);
                    end
                end
            catch
                % 使用預設姿態
            end
        end
        
        function status_info = get_drone_status_info(obj, drone_id)
            % 獲取無人機狀態信息
            status_info = 'ACTIVE';
            
            try
                if obj.simulator.drones.isKey(drone_id)
                    drone_data = obj.simulator.drones(drone_id);
                    current_time = obj.simulator.current_time;
                    
                    if isfield(drone_data, 'trajectory') && ~isempty(drone_data.trajectory)
                        current_pos = obj.interpolate_position(drone_data.trajectory, current_time);
                        if ~isempty(current_pos) && isfield(current_pos, 'phase')
                            status_info = upper(current_pos.phase);
                        end
                    end
                end
            catch
                status_info = 'UNKNOWN';
            end
        end
        
        function is_valid = is_valid_position(obj, position)
            % 檢查位置是否有效
            is_valid = ~isempty(position) && ...
                       isfield(position, 'x') && isfield(position, 'y') && isfield(position, 'z') && ...
                       ~isnan(position.x) && ~isnan(position.y) && ~isnan(position.z);
        end
        
        function render_fallback_representation(obj, position)
            % 降級表示 (當3D渲染失敗時)
            plot3(obj.plot_axes, position(1), position(2), position(3), ...
                  'd', 'MarkerSize', 8, 'MarkerFaceColor', 'blue', ...
                  'MarkerEdgeColor', 'white', 'LineWidth', 1);
        end
        
        % === 模型創建工具方法 ===
        
        function [x, y, z] = create_cylinder(obj, start_pos, end_pos, radius, segments)
            % 創建圓柱體
            direction = end_pos - start_pos;
            length = norm(direction);
            
            if length == 0
                x = []; y = []; z = [];
                return;
            end
            
            % 標準圓柱體
            [X, Y, Z] = cylinder(radius, segments);
            Z = Z * length;
            
            % 旋轉到正確方向 (簡化實現)
            x = X + start_pos(1);
            y = Y + start_pos(2);
            z = Z + start_pos(3);
        end
        
        function model = create_box_model(obj, center, length, width, height)
            % 創建箱型模型
            model = struct();
            
            % 箱體頂點
            vertices = [
                -length/2, -width/2, -height/2;
                +length/2, -width/2, -height/2;
                +length/2, +width/2, -height/2;
                -length/2, +width/2, -height/2;
                -length/2, -width/2, +height/2;
                +length/2, -width/2, +height/2;
                +length/2, +width/2, +height/2;
                -length/2, +width/2, +height/2;
            ];
            
            % 平移到中心位置
            vertices = vertices + repmat(center, 8, 1);
            
            % 面定義 (立方體的6個面)
            faces = [
                1, 2, 3, 4;  % 底面
                5, 6, 7, 8;  % 頂面
                1, 2, 6, 5;  % 前面
                3, 4, 8, 7;  % 後面
                1, 4, 8, 5;  % 左面
                2, 3, 7, 6;  # 右面
            ];
            
            model.vertices = vertices;
            model.faces = faces;
            
        end
        
        function model = create_cylinder_model(obj, center, radius, height)
            % 創建圓柱體模型
            segments = 16;
            [X, Y, Z] = cylinder(radius, segments);
            Z = Z * height - height/2; % 中心對齊
            
            % 平移到指定位置
            X = X + center(1);
            Y = Y + center(2);
            Z = Z + center(3);
            
            model = struct();
            model.vertices = [X(:), Y(:), Z(:)];
            model.faces = obj.generate_cylinder_faces(size(X, 1), size(X, 2));
        end
        
        function model = create_sphere_model(obj, center, radius)
            % 創建球體模型
            [X, Y, Z] = sphere(16);
            X = X * radius + center(1);
            Y = Y * radius + center(2);
            Z = Z * radius + center(3);
            
            model = struct();
            model.vertices = [X(:), Y(:), Z(:)];
            model.faces = obj.generate_sphere_faces(size(X, 1));
        end
        
        function propeller = create_propeller_model(obj, center, radius, blade_count)
            % 創建螺旋槳模型
            propeller = struct();
            propeller.blades = cell(blade_count, 1);
            
            for i = 1:blade_count
                angle = (i-1) * (360/blade_count);
                
                % 簡化的槳葉模型 (橢圓)
                blade_length = radius * 0.9;
                blade_width = radius * 0.1;
                
                % 創建槳葉幾何
                theta = linspace(0, 2*pi, 16);
                blade_x = blade_length * cos(theta);
                blade_y = blade_width * sin(theta);
                blade_z = zeros(size(theta));
                
                # 旋轉到正確角度
                cos_a = cosd(angle);
                sin_a = sind(angle);
                
                rotated_x = blade_x * cos_a - blade_y * sin_a;
                rotated_y = blade_x * sin_a + blade_y * cos_a;
                
                # 平移到螺旋槳中心
                rotated_x = rotated_x + center(1);
                rotated_y = rotated_y + center(2);
                blade_z = blade_z + center(3);
                
                propeller.blades{i} = struct();
                propeller.blades{i}.vertices = [rotated_x(:), rotated_y(:), blade_z(:)];
                propeller.blades{i}.color = [0.2, 0.2, 0.2]; % 黑色槳葉
            end
            
            propeller.center = center;
            propeller.radius = radius;
            propeller.rotation_angle = 0; % 當前旋轉角度
        end
        
        function faces = generate_cylinder_faces(obj, rows, cols)
            % 生成圓柱體面索引
            faces = [];
            
            % 簡化面生成邏輯
            for i = 1:(rows-1)
                for j = 1:(cols-1)
                    v1 = (i-1)*cols + j;
                    v2 = (i-1)*cols + j + 1;
                    v3 = i*cols + j + 1;
                    v4 = i*cols + j;
                    
                    faces = [faces; v1, v2, v3, v4];
                end
            end
        end
        
        function faces = generate_sphere_faces(obj, resolution)
            % 生成球體面索引 (簡化)
            faces = [];
            
            % 這裡可以實現更複雜的球體面生成算法
            % 暫時返回空數組，實際使用中會用patch的預設面生成
        end
        
        function faces = generate_ellipsoid_faces(obj, rows, cols)
            % 生成橢球面索引
            faces = obj.generate_sphere_faces(rows); % 重用球體邏輯
        end
    end
end