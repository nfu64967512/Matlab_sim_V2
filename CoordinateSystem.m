classdef CoordinateSystem < handle
    % 座標系統轉換器類別
    % 負責GPS座標與本地直角座標系的相互轉換
    
    properties
        origin_lat              % 原點緯度
        origin_lon              % 原點經度
        meters_per_degree_lat   % 每度緯度的公尺數
        meters_per_degree_lon   % 每度經度的公尺數
    end
    
    properties (Constant)
        EARTH_RADIUS = 6378137.0            % 地球半徑 (公尺)
        METERS_PER_DEGREE_LAT = 111111.0    % 緯度每度公尺數（近似）
    end
    
    methods
        function obj = CoordinateSystem()
            % 建構函數
            obj.origin_lat = [];
            obj.origin_lon = [];
            obj.meters_per_degree_lat = obj.METERS_PER_DEGREE_LAT;
            obj.meters_per_degree_lon = [];
            
            fprintf('座標系統轉換器已初始化\n');
        end
        
        function set_origin(obj, lat, lon)
            % 設置座標原點
            obj.origin_lat = lat;
            obj.origin_lon = lon;
            
            % 計算該緯度下經度每度的公尺數
            obj.meters_per_degree_lon = obj.METERS_PER_DEGREE_LAT * cos(deg2rad(lat));
            
            fprintf('座標原點設置為: (%.8f, %.8f)\n', lat, lon);
            fprintf('經度每度公尺數: %.2f\n', obj.meters_per_degree_lon);
        end
        
        function [x, y] = lat_lon_to_meters(obj, lat, lon)
            % GPS座標轉換為本地公尺座標
            if isempty(obj.origin_lat) || isempty(obj.origin_lon)
                error('座標原點未設置，請先調用 set_origin()');
            end
            
            % 計算與原點的差值
            delta_lat = lat - obj.origin_lat;
            delta_lon = lon - obj.origin_lon;
            
            % 轉換為公尺
            y = delta_lat * obj.meters_per_degree_lat;
            x = delta_lon * obj.meters_per_degree_lon;
        end
        
        function [lat, lon] = meters_to_lat_lon(obj, x, y)
            % 本地公尺座標轉換為GPS座標
            if isempty(obj.origin_lat) || isempty(obj.origin_lon)
                error('座標原點未設置，請先調用 set_origin()');
            end
            
            % 轉換為度數差值
            delta_lat = y / obj.meters_per_degree_lat;
            delta_lon = x / obj.meters_per_degree_lon;
            
            % 計算絕對座標
            lat = obj.origin_lat + delta_lat;
            lon = obj.origin_lon + delta_lon;
        end
        
        function distance = calculate_gps_distance(~, lat1, lon1, lat2, lon2)
            % 計算兩個GPS點之間的距離（使用Haversine公式）
            R = 6378137.0; % 地球半徑
            
            % 轉換為弧度
            lat1_rad = deg2rad(lat1);
            lon1_rad = deg2rad(lon1);
            lat2_rad = deg2rad(lat2);
            lon2_rad = deg2rad(lon2);
            
            % Haversine公式
            dlat = lat2_rad - lat1_rad;
            dlon = lon2_rad - lon1_rad;
            
            a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2;
            c = 2 * atan2(sqrt(a), sqrt(1-a));
            
            distance = R * c;
        end
        
        function is_valid = is_origin_set(obj)
            % 檢查原點是否已設置
            is_valid = ~isempty(obj.origin_lat) && ~isempty(obj.origin_lon);
        end
        
        function reset_origin(obj)
            % 重置座標原點
            obj.origin_lat = [];
            obj.origin_lon = [];
            obj.meters_per_degree_lon = [];
            fprintf('座標原點已重置\n');
        end
    end
end