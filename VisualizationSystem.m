classdef VisualizationSystem < handle
    % 3D視覺化系統類別
    % 負責無人機軌跡的3D顯示、實時更新和狀態監控
    
    properties
        simulator           % 主模擬器引用
        plot_axes          % 3D繪圖軸
        trajectory_plots   % 軌跡繪圖句柄
        drone_markers      % 無人機標記句柄
        collision_lines    % 碰撞警告線
        animation_timer    % 動畫定時器
        view_settings      % 視角設定
    end
    
    methods
        function obj = VisualizationSystem(simulator)
            % 建構函數
            obj.simulator = simulator;
            obj.trajectory_plots = containers.Map();
            obj.drone_markers = containers.Map();
            obj.collision_lines = {};
            obj.view_settings = struct('azimuth', 45, 'elevation', 30);
            
            fprintf('3D視覺化系統已初始化\n');
        end
        
        function setup_3d_axes(obj, axes_handle)
            % 設置3D繪圖軸
            obj.plot_axes = axes_handle;
            
            % 設置軸屬性
            set(obj.plot_axes, 'Color', 'black');
            set(obj.plot_axes, 'XColor', 'white');
            set(obj.plot_axes, 'YColor', 'white');  
            set(obj.plot_axes, 'ZColor', 'white');
            
            hold(obj.plot_axes, 'on');
            grid(obj.plot_axes, 'on');
            set(obj.plot_axes, 'GridColor', [0.3, 0.3, 0.3]);
            set(obj.plot_axes, 'GridAlpha', 0.5);
            
            % 設置軸標籤
            xlabel(obj.plot_axes, 'X (公尺)', 'Color', 'white', 'FontSize', 12);
            ylabel(obj.plot_axes, 'Y (公尺)', 'Color', 'white', 'FontSize', 12);
            zlabel(obj.plot_axes, 'Z (公尺)', 'Color', 'white', 'FontSize', 12);
            
            title(obj.plot_axes, '無人機群飛軌跡實時預覽', ...
                  'Color', 'cyan', 'FontSize', 14, 'FontWeight', 'bold');
            
            % 啟用3D旋轉和縮放
            rotate3d(obj.plot_axes, 'on');
            zoom(obj.plot_axes, 'on');
            
            % 設置初始視角
            view(obj.plot_axes, obj.view_settings.azimuth, obj.view_settings.elevation);
        end
        
        function update_3d_plot(obj)
            % 更新3D繪圖的主函數
            if isempty(obj.plot_axes) || ~isvalid(obj.plot_axes)
                return;
            end
            
            % 清除現有繪圖（保留軸設定）
            cla(obj.plot_axes);
            hold(obj.plot_axes, 'on');
            
            % 重新設置軸屬性（因為cla會清除）
            obj.setup_axes_properties();
            
            % 繪製所有無人機軌跡
            obj.plot_all_trajectories();
            
            % 繪製當前位置標記
            obj.plot_current_positions();
            
            % 顯示碰撞警告
            obj.plot_collision_warnings();
            
            % 更新信息覆蓋層
            obj.update_info_overlay();
            
            % 設置最佳視角和範圍
            obj.set_optimal_view();
            
            drawnow;
        end
        
        function setup_axes_properties(obj)
            % 設置軸屬性（內部使用）
            set(obj.plot_axes, 'Color', 'black');
            set(obj.plot_axes, 'XColor', 'white');
            set(obj.plot_axes, 'YColor', 'white');
            set(obj.plot_axes, 'ZColor', 'white');
            
            grid(obj.plot_axes, 'on');
            set(obj.plot_axes, 'GridColor', [0.3, 0.3, 0.3]);
            set(obj.plot_axes, 'GridAlpha', 0.5);
            
            xlabel(obj.plot_axes, 'X (公尺)', 'Color', 'white', 'FontSize', 12);
            ylabel(obj.plot_axes, 'Y (公尺)', 'Color', 'white', 'FontSize', 12);
            zlabel(obj.plot_axes, 'Z (公尺)', 'Color', 'white', 'FontSize', 12);
            
            title(obj.plot_axes, '無人機群飛軌跡實時預覽 | 右鍵拖拽旋轉，滾輪縮放', ...
                  'Color', 'cyan', 'FontSize', 14, 'FontWeight', 'bold');
        end
        
        function plot_all_trajectories(obj)
            % 繪製所有無人機軌跡
            drone_keys = obj.simulator.drones.keys;
            
            if isempty(drone_keys)
                return;
            end
            
            legend_entries = {};
            
            for i = 1:length(drone_keys)
                drone_id = drone_keys{i};
                drone_data = obj.simulator.drones(drone_id);
                
                if ~isempty(drone_data.trajectory)
                    obj.plot_single_trajectory(drone_id, drone_data);
                    legend_entries{end+1} = drone_id; %#ok<AGROW>
                end
            end
            
            % 添加圖例
            if ~isempty(legend_entries)
                legend(obj.plot_axes, legend_entries, 'Location', 'northeast', ...
                       'TextColor', 'white', 'EdgeColor', 'white');
            end
        end
        
        function plot_single_trajectory(obj, drone_id, drone_data)
            % 繪製單一無人機軌跡
            trajectory = drone_data.trajectory;
            
            if isempty(trajectory)
                return;
            end
            
            % 提取座標
            x_coords = [trajectory.x];
            y_coords = [trajectory.y];
            z_coords = [trajectory.z];
            
            % 繪製軌跡線
            plot3(obj.plot_axes, x_coords, y_coords, z_coords, ...
                  'Color', drone_data.color, 'LineWidth', 2, 'DisplayName', drone_id);
            
            % 標記起點
            if length(trajectory) > 0
                start_point = trajectory(1);
                plot3(obj.plot_axes, start_point.x, start_point.y, start_point.z, ...
                      'o', 'MarkerSize', 10, 'MarkerFaceColor', 'green', ...
                      'MarkerEdgeColor', 'white', 'LineWidth', 2);
                
                % 起點標籤
                text(obj.plot_axes, start_point.x, start_point.y, start_point.z + 3, ...
                     '起點', 'Color', 'green', 'FontSize', 9, ...
                     'HorizontalAlignment', 'center');
            end
            
            % 標記終點
            if length(trajectory) > 1
                end_point = trajectory(end);
                plot3(obj.plot_axes, end_point.x, end_point.y, end_point.z, ...
                      's', 'MarkerSize', 10, 'MarkerFaceColor', 'red', ...
                      'MarkerEdgeColor', 'white', 'LineWidth', 2);
                
                % 終點標籤
                text(obj.plot_axes, end_point.x, end_point.y, end_point.z + 3, ...
                     '終點', 'Color', 'red', 'FontSize', 9, ...
                     'HorizontalAlignment', 'center');
            end
        end
        
        function plot_current_positions(obj)
            % 繪製當前位置標記
            current_time = obj.simulator.current_time;
            
            if current_time <= 0
                return;
            end
            
            drone_keys = obj.simulator.drones.keys;
            
            for i = 1:length(drone_keys)
                drone_id = drone_keys{i};
                drone_data = obj.simulator.drones(drone_id);
                
                if ~isempty(drone_data.trajectory)
                    % 獲取當前位置
                    current_pos = obj.interpolate_position(drone_data.trajectory, current_time);
                    
                    if ~isempty(current_pos)
                        % 繪製無人機圖標
                        obj.plot_drone_icon(current_pos, drone_id);
                        
                        % 繪製安全半徑
                        obj.plot_safety_radius(current_pos);
                    end
                end
            end
        end
        
        function current_pos = interpolate_position(~, trajectory, current_time)
            % 插值計算當前位置
            current_pos = [];
            
            if isempty(trajectory)
                return;
            end
            
            times = [trajectory.time];
            
            if current_time <= times(1)
                current_pos = trajectory(1);
            elseif current_time >= times(end)
                current_pos = trajectory(end);
            else
                % 線性插值
                idx = find(times <= current_time, 1, 'last');
                if idx < length(times)
                    t1 = times(idx);
                    t2 = times(idx + 1);
                    
                    if t2 > t1
                        ratio = (current_time - t1) / (t2 - t1);
                    else
                        ratio = 0;
                    end
                    
                    p1 = trajectory(idx);
                    p2 = trajectory(idx + 1);
                    
                    current_pos = struct();
                    current_pos.x = p1.x + ratio * (p2.x - p1.x);
                    current_pos.y = p1.y + ratio * (p2.y - p1.y);
                    current_pos.z = p1.z + ratio * (p2.z - p1.z);
                    current_pos.phase = p1.phase;
                    current_pos.time = current_time;
                else
                    current_pos = trajectory(end);
                end
            end
        end
        
        function plot_drone_icon(obj, position, drone_id)
            % 繪製無人機圖標
            x = position.x;
            y = position.y;
            z = position.z;
            
            % 無人機主體（使用五角星形狀）
            plot3(obj.plot_axes, x, y, z, ...
                  'p', 'MarkerSize', 15, 'MarkerFaceColor', 'yellow', ...
                  'MarkerEdgeColor', 'black', 'LineWidth', 2);
            
            % 無人機標籤
            text(obj.plot_axes, x, y, z + 4, drone_id, ...
                 'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold', ...
                 'HorizontalAlignment', 'center', ...
                 'BackgroundColor', 'black', 'EdgeColor', 'white');
        end
        
        function plot_safety_radius(obj, position)
            % 繪製安全半徑圓圈
            safety_radius = obj.simulator.safety_distance;
            
            % 創建水平圓形
            theta = linspace(0, 2*pi, 50);
            circle_x = position.x + safety_radius * cos(theta);
            circle_y = position.y + safety_radius * sin(theta);
            circle_z = position.z * ones(size(theta));
            
            plot3(obj.plot_axes, circle_x, circle_y, circle_z, ...
                  '--', 'Color', [1, 1, 0, 0.4], 'LineWidth', 1);
        end
        
        function plot_collision_warnings(obj)
            % 繪製碰撞警告
            if isempty(obj.simulator.collision_system) || ...
               isempty(obj.simulator.collision_system.collision_warnings)
                return;
            end
            
            warnings = obj.simulator.collision_system.collision_warnings;
            
            for i = 1:length(warnings)
                warning = warnings{i};
                obj.plot_collision_indicator(warning);
            end
        end
        
        function plot_collision_indicator(obj, warning)
            % 繪製單個碰撞警告指示器
            current_time = obj.simulator.current_time;
            
            % 獲取兩架無人機的當前位置
            drone1_data = obj.simulator.drones(warning.drone1);
            drone2_data = obj.simulator.drones(warning.drone2);
            
            pos1 = obj.interpolate_position(drone1_data.trajectory, current_time);
            pos2 = obj.interpolate_position(drone2_data.trajectory, current_time);
            
            if ~isempty(pos1) && ~isempty(pos2)
                % 繪製警告連接線
                plot3(obj.plot_axes, [pos1.x, pos2.x], [pos1.y, pos2.y], [pos1.z, pos2.z], ...
                      'r-', 'LineWidth', 4, 'Color', [1, 0, 0, 0.8]);
                
                % 中點警告標記
                mid_x = (pos1.x + pos2.x) / 2;
                mid_y = (pos1.y + pos2.y) / 2;
                mid_z = (pos1.z + pos2.z) / 2;
                
                plot3(obj.plot_axes, mid_x, mid_y, mid_z, ...
                      'x', 'MarkerSize', 20, 'Color', 'red', 'LineWidth', 5);
                
                % 警告文字
                warning_text = sprintf('WARNING %.1fm', warning.distance);
                text(obj.plot_axes, mid_x, mid_y, mid_z + 6, warning_text, ...
                     'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold', ...
                     'HorizontalAlignment', 'center');
            end
        end
        
        function update_info_overlay(obj)
            % 更新信息覆蓋層（修正MATLAB 2025a兼容性）
            current_time = obj.simulator.current_time;
            max_time = obj.simulator.max_time;
            
            % 計算活躍無人機數量
            active_drones = 0;
            total_drones = obj.simulator.drones.Count;
            
            drone_keys = obj.simulator.drones.keys;
            for i = 1:length(drone_keys)
                drone_data = obj.simulator.drones(drone_keys{i});
                if ~isempty(drone_data.trajectory) && current_time <= drone_data.trajectory(end).time
                    active_drones = active_drones + 1;
                end
            end
            
            % GPU狀態
            gpu_status = obj.simulator.get_gpu_status_string();
            
            % 碰撞警告數量
            warning_count = 0;
            if ~isempty(obj.simulator.collision_system)
                warning_count = length(obj.simulator.collision_system.collision_warnings);
            end
            
            % 組合信息文字
            info_text = sprintf(['時間: %.1fs / %.1fs\n', ...
                               '無人機: %d/%d 活躍\n', ...
                               '計算模式: %s\n', ...
                               '安全距離: %.1fm\n', ...
                               '碰撞警告: %d'], ...
                               current_time, max_time, ...
                               active_drones, total_drones, ...
                               gpu_status, ...
                               obj.simulator.safety_distance, ...
                               warning_count);
            
            % 在左上角顯示信息（移除可能不支援的屬性）
            try
                text(obj.plot_axes, 0.02, 0.98, 0, info_text, ...
                     'Units', 'normalized', ...
                     'Color', 'cyan', 'FontSize', 11, 'FontWeight', 'bold', ...
                     'BackgroundColor', 'black', 'EdgeColor', 'cyan');
            catch
                % 如果text函數有問題，使用更簡單的方式
                title(obj.plot_axes, info_text, 'Color', 'cyan', 'FontSize', 11);
            end
        end
        
        function set_optimal_view(obj)
            % 設置最佳視角和範圍
            drone_keys = obj.simulator.drones.keys;
            
            if isempty(drone_keys)
                return;
            end
            
            % 計算所有軌跡的邊界
            all_x = [];
            all_y = [];
            all_z = [];
            
            for i = 1:length(drone_keys)
                drone_data = obj.simulator.drones(drone_keys{i});
                if ~isempty(drone_data.trajectory)
                    trajectory = drone_data.trajectory;
                    all_x = [all_x, [trajectory.x]]; %#ok<AGROW>
                    all_y = [all_y, [trajectory.y]]; %#ok<AGROW>
                    all_z = [all_z, [trajectory.z]]; %#ok<AGROW>
                end
            end
            
            if ~isempty(all_x)
                % 計算範圍
                x_range = [min(all_x), max(all_x)];
                y_range = [min(all_y), max(all_y)];
                z_range = [min(all_z), max(all_z)];
                
                % 添加邊距
                x_margin = max((x_range(2) - x_range(1)) * 0.15, 10);
                y_margin = max((y_range(2) - y_range(1)) * 0.15, 10);
                z_margin = max((z_range(2) - z_range(1)) * 0.15, 5);
                
                % 設置軸範圍
                xlim(obj.plot_axes, [x_range(1) - x_margin, x_range(2) + x_margin]);
                ylim(obj.plot_axes, [y_range(1) - y_margin, y_range(2) + y_margin]);
                zlim(obj.plot_axes, [max(z_range(1) - z_margin, 0), z_range(2) + z_margin]);
                
                % 設置等比例軸
                axis(obj.plot_axes, 'equal');
            end
            
            % 設置視角
            view(obj.plot_axes, obj.view_settings.azimuth, obj.view_settings.elevation);
        end
        
        function start_animation(obj)
            % 開始動畫（預留接口，主要由模擬器定時器驅動）
            fprintf('視覺化動畫已啟動\n');
        end
        
        function stop_animation(obj)
            % 停止動畫（預留接口）
            fprintf('視覺化動畫已停止\n');
        end
        
        function reset_view(obj)
            % 重置視角
            obj.view_settings.azimuth = 45;
            obj.view_settings.elevation = 30;
            
            if ~isempty(obj.plot_axes) && isvalid(obj.plot_axes)
                view(obj.plot_axes, obj.view_settings.azimuth, obj.view_settings.elevation);
                axis(obj.plot_axes, 'equal');
            end
            
            fprintf('視角已重置\n');
        end
    end
end