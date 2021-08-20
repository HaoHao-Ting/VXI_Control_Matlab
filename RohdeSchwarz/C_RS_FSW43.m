% 适用于罗德FSW43频谱仪的一些控制命令
% obj = C_RS_FSW43('102.10.1.1'); 根据IP地址连接设备
% obj.saveASCII('C:\1.csv'); 将频谱数据以ASCII格式保存到仪器中
% [fre, power] = obj.getMaxPeak(); 获取频谱最高峰的幅度和频率
% [X, Y] = getMarkerN(obj, iMarker); % 获取Marker i对应的频率和幅度 
classdef C_RS_FSW43
    properties
        interface = 0;
    end

    methods
        function obj = C_RS_FSW43(ipAddress)
            rsrcName = ['TCPIP0::', ipAddress, '::hislip0::INSTR'];
            obj.interface = instrfind('Type', 'visa-tcpip', 'RsrcName', rsrcName, 'Tag', '');
            if isempty(obj.interface)
                obj.interface = visa('KEYSIGHT', rsrcName);
            else
                fclose(obj.interface);
                obj.interface = obj.interface(1);
            end
            fopen(obj.interface);
        end

        %! SAVE DATA TO Deviec
        function saveASCII(obj, filePath)
            fprintf(obj.interface, ...
                sprintf("MMEM:STORE1:TRAC 1, '%s'", filePath));
        end

        %! Get Max Peak
        function [X, Y] = getMaxPeak(obj)
            fprintf(obj.interface, ':Calc1:Marker1 On');
            fprintf(obj.interface, ':Calc1:Marker1:Max:Peak');
            data0 = query(obj.interface, ':Calc1:Marker1:X?;Y?');
            data1 = split(data0, ';');
            X = str2num(data1{1});
            Y = str2num(data1{2});
        end

        function [X, Y] = getMarkerN(obj, iMarker)
            data0 = query(obj.interface, sprintf(':Calc1:Marker%d:X?;Y?', iMarker));
            data1 = split(data0, ';');
            X = str2num(data1{1});
            Y = str2num(data1{2});
        end
        function close(obj)
            fclose(obj.interface);
        end
    end
end
