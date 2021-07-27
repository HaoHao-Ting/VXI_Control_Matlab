
% 使用说明 适用于罗德SMW200A的控制程序
% obj = C_RS_SMW200A('192.158.1.1'); 连接设备
% obj.setFre(10e9); 设置频率
% obj.setLevel(10); 设置幅度
% obj.on(); 开输出
% obj.off(); 关输出
% fre = obj.getFre(); 获取当前频率
% level = obj.getLevel(); 获取当前幅度
% obj.close(); 断开连接

classdef C_RS_SMW200A
    properties
        interface = 0;
    end
    methods
        function obj = C_RS_SMW200A(ipAddress)
            rsrcName = ['TCPIP0::', ipAddress,'::hislip0::INSTR'];
            obj.interface = instrfind('Type', 'visa-tcpip', 'RsrcName', rsrcName, 'Tag', '');
            if isempty(obj.interface)
                obj.interface = visa('KEYSIGHT', rsrcName);
            else
                fclose(obj.interface);
                obj.interface = obj.interface(1);
            end
            fopen(obj.interface);
        end
        %! 设置频率
        function setFre(obj, fre)
            fprintf(obj.interface, ['FREQ:CW ', num2str(fre)]);
        end
        %! 获取频率
        function fre = getFre(obj)
            fre = query(obj.interface, 'FREQ:CW?');
            fre = str2double(fre);
        end
        %! 设置幅度
        function setLevel(obj, level)
            fprintf(obj.interface, ['Sourcel:Power:Power ', num2str(level)]);
        end
        %! 获取幅度
        function level = getLevel(obj)
            level = query(obj.interface, 'Sourcel:Power:Power?');
            level = str2double(level);
        end
        %! 打开输出
        function on(obj)
            fprintf(obj.interface, 'OUTPUT1 1');
        end
        %! 关闭输出
        function off(obj)
            fprintf(obj.interface, 'OUTPUT1 0');
        end
        %! 断开连接
        function close(obj)
            fclose(obj.interface);
        end
    end
end
