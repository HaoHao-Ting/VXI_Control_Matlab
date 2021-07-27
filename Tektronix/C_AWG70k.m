%% 使用说明 控制泰克的AWG 70000系列
% obj = AWG70k('192.158.1.1'); 连接设备
% obj.setFre(10e9); 设置频率
% fre = obj.getFre(); 获取当前采样率
% obj.setLevel(0.5); 设置0.5mVpp
% level = obj.getLevel(); 获取峰峰值
% obj.on(); 开输出通道
% obj.off(); 关输出通道
% obj.play(); play
% obj.stop(); stop
% obj.close(); 断开连接
% obj.sendWfm(wfmData, wfmName); 发送波形数据到AWG
% obj.sendMarker(markerData, wfmName)
classdef C_AWG70k
    properties
        interface = 0;
        buffer = 10 * 1024 * 1024; % 传输到AWG的buffer大小
    end
    methods
        function obj = C_AWG70k(ipAddress)
            rsrcName = ['TCPIP0::', ipAddress, '::inst0::INSTR'];
            obj.interface = instrfind('Type', 'visa-tcpip', 'RsrcName', rsrcName, 'Tag', '');
            if isempty(obj.interface)
                obj.interface = visa('KEYSIGHT', rsrcName);
            else
                fclose(obj.interface);
                obj.interface = obj.interface(1);
            end
            obj.interface.OutputBufferSize = obj.buffer;
            fopen(obj.interface);
        end

        function setFre(obj, fre)
            fprintf(obj.interface, ['Clock:Srate ', num2str(fre)]);
        end
        function fre = getFre(obj)
            fre = query(obj.interface, 'Clock:Srate?');
            fre = str2double(fre);
        end

        function setLevel(level)
            fprintf(obj.interface, ...
                ['SOURCE1:VOLTAGE:LEVel:IMMediate:AMPLITUDE ', num2str(level)]);
        end
        function level = getLevel(obj)
            level = query(obj.interface, ...
                'SOURCE1:VOLTAGE:LEVel:IMMediate:AMPLITUDE?');
            level = str2double(level);
        end

        function on(obj)
            fprintf(obj.interface, 'OutPut1:State on');
        end
        function off(obj)
            fprintf(obj.interface, 'OutPut1:State off');
        end
        function play(obj)
            fprintf(obj.interface, 'AWGControl:RUN:IMMediate');
        end
        function stop(obj)
            fprintf(obj.interface, 'AWGControl:STOP:IMMediate');
        end

        function close(obj)
            fclose(obj.interface);
        end

        function sendWfm(obj, wfmData, wfmName)
            linefeed = 10;
            awg = obj.interface;
            % status check
            r = query(awg, '*esr?', '%s', '%d');
            fprintf(1, 'event status register: %d\n', r);
            % read all messages until No error
            fprintf(1, 'messages:\n');
            while 1
                r = query(awg, 'syst:err?');
                fprintf(1, '* %s', r);
                if strcmp(r, ['0,"No error"', linefeed])
                    break
                end
            end
            % awg70k requires single precision vectors
            waveform_data = single(wfmData);
            waveform_samples = length(waveform_data);
            waveform_bytes = waveform_samples * 4;

            % command formatting
            delete_waveform = sprintf('wlist:waveform:delete "%s"', wfmName);
            fwrite(awg, delete_waveform);
            header = sprintf('#%d%d', length(num2str(waveform_bytes)), waveform_bytes);
            create_waveform = sprintf('wlist:waveform:new "%s", %d', wfmName, length(waveform_data));
            fwrite(awg, create_waveform);

            write_waveform_binblock = sprintf('wlist:waveform:data "%s", %s', wfmName, header);
            fwrite(awg, write_waveform_binblock);
            awg.EOIMode = 'off';
            if obj.buffer >= waveform_bytes
                fwrite(awg, waveform_data, 'single');
            else
                sample_buffer = floor(obj.buffer/4);
                for a = 1:sample_buffer:waveform_samples - sample_buffer
                    fwrite(awg, waveform_data(a:a + sample_buffer - 1), 'single');
                end
                a = a + sample_buffer;
                fwrite(awg, waveform_data(a:end), 'single');
            end
            awg.EOIMode = 'on';
            fwrite(awg, linefeed);
            assign_waveform_ch1 = sprintf('source1:waveform "%s"', wfmName);
            fwrite(awg, assign_waveform_ch1);
            % 启动脉冲输出
            obj.run();
        end

        function sendMarker(obj, marker_input, wfmName)
            linefeed = 10;
            awg = obj.interface;
            % status check
            r = query(awg, '*esr?', '%s', '%d');
            fprintf(1, 'event status register: %d\n', r);
            % read all messages until No error
            fprintf(1, 'messages:\n');
            while 1
                r = query(awg, 'syst:err?');
                fprintf(1, '* %s', r);
                if strcmp(r, ['0,"No error"', linefeed])
                    break
                end
            end

            marker1_data = zeros(1, size(marker_input, 1), 'uint8');
            marker1_data(logical(marker_input(:, 1))) = 64;
            if (size(marker_input, 2) == 2)
                marker2_data = zeros(1, size(marker_input, 1), 'uint8');
                marker2_data(logical(marker_input(:, 2))) = 128;
                marker_data = marker1_data + marker2_data;
            else
                marker_data = marker1_data;
            end
            clear marker1_data marker2_data;

            nData = length(marker_data);
            nBytesData = nData * 1; % n bytes with n data points

            header_marker = sprintf('#%d%d', length(num2str(nBytesData)), nBytesData);
            write_waveform_makrker = sprintf('wlist:waveform:marker:data "%s", %s', wfmName, header_marker);

            fwrite(awg, write_waveform_makrker);
            awg.EOIMode = 'off';
            if obj.buffer >= nBytesData
                fwrite(awg, marker_data, 'uint8');
            else
                marker_buffer = floor(obj.buffer);
                for a = 1:marker_buffer:nData - marker_buffer
                    fwrite(awg, marker_data(a:a + marker_buffer - 1), 'uint8');
                end
                a = a + marker_buffer;
                fwrite(awg, marker_data(a:end), 'uint8');
            end
            awg.EOIMode = 'on';
            fwrite(awg, linefeed);
            % status check after transfer
            r = query(awg, '*esr?', '%s', '%d');
            fprintf(1, 'event status register: %d\n', r);
            % read all messages until No error
            fprintf(1, 'messages:\n');
            while 1
                r = query(awg, 'syst:err?');
                fprintf(1, '* %s', r);
                if strcmp(r, ['0,"No error"', linefeed])
                    break
                end
            end
        end
    end
end
