% �������޵�FSW43Ƶ���ǵ�һЩ��������
% obj = C_RS_FSW43('102.10.1.1'); ����IP��ַ�����豸
% obj.saveASCII('C:\1.csv'); ��Ƶ��������ASCII��ʽ���浽������
% [fre, power] = obj.getMaxPeak(); ��ȡƵ����߷�ķ��Ⱥ�Ƶ��
% [X, Y] = getMarkerN(obj, iMarker); % ��ȡMarker i��Ӧ��Ƶ�ʺͷ��� 
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
