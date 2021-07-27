% 使用说明 适用于安捷伦N9010A频谱仪的控制
% obj = C_EXA_N9010A('192.158.1.1'); 连接设备
% obj.setBandWidth(100); 设置BW为100Hz
% obj.setCenterFre(1e9); 设置中心频率1GHz
% obj.setSpan(10e6); 设置Span大小10Mz
% obj.setMarkerX(fre, 1); 设置marker 1 的位置
% obj.setMarkerToPeak(1) 设置marker1 到峰值
% power = obj.getMarkerPower(1);  获取marker1的功率值
% fre = obj.getMarkerFre(1); 获取Marker1的频率值
% data = obj.saveData()
% obj.close(); 断开连接


classdef C_EXA_N9010A
    properties
        interface = 0;
        ipAddress = '';
    end
    methods
        function obj = C_EXA_N9010A(ipAddress)
            obj.ipAddress = ipAddress;
            rsrcName = ['TCPIP0::', ipAddress,'::inst0::INSTR'];
            obj.interface = instrfind('Type', 'visa-tcpip', 'RsrcName', rsrcName, 'Tag', '');
            if isempty(obj.interface)
                obj.interface = visa('KEYSIGHT', rsrcName);
            else
                fclose(obj.interface);
                obj.interface = obj.interface(1);
            end
            fopen(obj.interface);
        end
        function run(obj)
            command0 = ':INITiate:CONTinuous 1';
            fprintf(obj.interface, command0);
        end
        function stop(obj)
            command0 = ':INITiate:CONTinuous 0';
            fprintf(obj.interface, command0);
        end
        %! 设置BW
        function setBandWidth(obj, fre)
            command0 = sprintf(':bandwidth:RES %eHz', fre);
            fprintf(obj.interface, command0);
        end
        function setCenterFre(obj, fre)
            command0 = sprintf(':FREQuency:CENTer %eHz', fre);
            fprintf(obj.interface, command0);
        end
        function setSpan(obj, fre)
            command0 = sprintf(':FREQuency:SPAN %eHz', fre);
            fprintf(obj.interface, command0);
        end
        function setMarkerX(obj, fre, id)
            command0 = sprintf(':CALCulate:MARKer%d:X %eHz', id, fre);
            fprintf(obj.interface, command0);
        end
        function setMarkerToPeak(obj, id)
            command0 = sprintf(':Calculate:Marker%d:CPSearch 1', id);
            fprintf(obj.interface, command0);
        end
        function power = getMarkerPower(obj, id)
            command0 = sprintf(':CALCulate:MARKer%d:Y?', id);
            power = query(obj.interface, command0);
        end
        function fre = getMarkerFre(obj, id)
            command0 = sprintf(':CALCulate:MARKer%d:X?', id);
            fre = query(obj.interface, command0);
        end
        function data = saveData(obj)
            options = weboptions('Timeout',Inf);
            fileName = 'tmp.csv';
            urlstr = sprintf('http://%s/Agilent.SA.WebInstrument/Trace1.csv', obj.ipAddress);
            outfilename = websave(fileName, urlstr, options);
            data = csvread('tmp.csv', 44,0);
        end

        % 断开设备
        function close(obj)
            fclose(obj.interface);
        end
    end
end
