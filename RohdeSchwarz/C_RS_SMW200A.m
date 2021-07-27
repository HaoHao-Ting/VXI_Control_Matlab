
% ʹ��˵�� �������޵�SMW200A�Ŀ��Ƴ���
% obj = C_RS_SMW200A('192.158.1.1'); �����豸
% obj.setFre(10e9); ����Ƶ��
% obj.setLevel(10); ���÷���
% obj.on(); �����
% obj.off(); �����
% fre = obj.getFre(); ��ȡ��ǰƵ��
% level = obj.getLevel(); ��ȡ��ǰ����
% obj.close(); �Ͽ�����

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
        %! ����Ƶ��
        function setFre(obj, fre)
            fprintf(obj.interface, ['FREQ:CW ', num2str(fre)]);
        end
        %! ��ȡƵ��
        function fre = getFre(obj)
            fre = query(obj.interface, 'FREQ:CW?');
            fre = str2double(fre);
        end
        %! ���÷���
        function setLevel(obj, level)
            fprintf(obj.interface, ['Sourcel:Power:Power ', num2str(level)]);
        end
        %! ��ȡ����
        function level = getLevel(obj)
            level = query(obj.interface, 'Sourcel:Power:Power?');
            level = str2double(level);
        end
        %! �����
        function on(obj)
            fprintf(obj.interface, 'OUTPUT1 1');
        end
        %! �ر����
        function off(obj)
            fprintf(obj.interface, 'OUTPUT1 0');
        end
        %! �Ͽ�����
        function close(obj)
            fclose(obj.interface);
        end
    end
end
