% 泰克示波器采集工具
% obj = C_TektronixOscilloscope('192.158.1.1', 10e9, 4e-6, [1,0,0,1]); 连接设备
% obj = C_TektronixOscilloscope('192.158.1.1', SampleRate, TimeDiv, ChanIdx); 连接设备
% C_TektronixOscilloscope.getData(); 采集数据
% C_TektronixOscilloscope.close(); 断开连接
classdef C_TektronixOscilloscope
    properties
        interface = 0;
        TimeDiv = 4e-6;   % 400ps/div
        SampleRate = 50e9;  % 100G??
        ChanIdx = [1,1,1,1];
    end
    methods
        function obj = C_TektronixOscilloscope(ipAddress, SampleRate, TimeDiv, ChanIdx)
            rsrcName = ['TCPIP0::', ipAddress,'::inst0::INSTR'];
            obj.interface = instrfind('Type', 'visa-tcpip', 'RsrcName', rsrcName, 'Tag', '');
            if isempty(obj.interface)
                obj.interface = visa('KEYSIGHT', rsrcName);
            else
                fclose(obj.interface);
                obj.interface = obj.interface(1);
            end
            % fopen(obj.interface);
            obj.TimeDiv = TimeDiv;
            obj.SampleRate = SampleRate;
            obj.ChanIdx = ChanIdx;
            interfaceObj_MSO72004C = obj.interface;
            EffChan = find(obj.ChanIdx); % 有效通道
            ChanNum = length(EffChan);
            RecordLen = obj.TimeDiv*obj.SampleRate*10 + 1; % 总时间长度10格
            
            tic
            %% 初始设置
            set(interfaceObj_MSO72004C, 'InputBufferSize', RecordLen*4);
            set(interfaceObj_MSO72004C, 'OutputBufferSize', RecordLen*4);
            set(interfaceObj_MSO72004C, 'Timeout', 10); % s，命令超时限制
            
            fopen(interfaceObj_MSO72004C); % 建立TekVISA协议连接
            fprintf(interfaceObj_MSO72004C, 'DATa:ENCdg SRIBinary'); % 波形文件的编码格式
            fprintf(interfaceObj_MSO72004C, 'WFMInpre:BYT_Nr 1'); % 每个数据点的字节数
            fprintf(interfaceObj_MSO72004C, 'WFMOutpre:Bit_Nr 8'); % 设定表示每数据点所需比特数（勿动）
            
            disp(['初始化:',num2str(toc),'秒'])
            tic
            
            %% 打开采集通道
            for m = 1:length(obj.ChanIdx) % 打开需要采集的通道
                if obj.ChanIdx(m)
                    fprintf(interfaceObj_MSO72004C, ['SELect:CH', num2str(m), ' ON']);
                end
            end
            pause(.5); % 等待所有通道打开
        end
       
        function WfmData = getData(obj)
            EffChan = find(obj.ChanIdx); % 有效通道
            ChanNum = length(EffChan);
            RecordLen = obj.TimeDiv*obj.SampleRate*10 + 1; % 总时间长度10格
            interfaceObj_MSO72004C = obj.interface;
            %% 采集数据
            fprintf(interfaceObj_MSO72004C, ['HORizontal:RECOrdlength ', num2str(RecordLen)]); % 记录长度
            fprintf(interfaceObj_MSO72004C, ['HORizontal:MODE:SAMPLERate ', num2str(obj.SampleRate)]); % 采样率
            fprintf(interfaceObj_MSO72004C, ['HORizontal:MODE:SCAle ', num2str(obj.TimeDiv)]); % 时间分辨率
            fprintf(interfaceObj_MSO72004C, 'ACQuire:MODE SAMple'); % 设置采集模式为采样    %%% PK Derect
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 这个地方非常重要 选择Peak Detect效果会更好
            % fprintf(interfaceObj_MSO72004C, 'ACQuire:MODE Peak'); % 设置采集模式为采样    %%% PK Derect
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fprintf(interfaceObj_MSO72004C, 'ACQuire:STOPAfter RUNStop'); % 设定下次采集模式，{RUNStop|SEQuence}，{连续|单次}
            
            pause(0.5);
            fprintf(interfaceObj_MSO72004C, 'ACQUIRE:STATE RUN'); % 开始采集
            ACQnum = str2double(query(interfaceObj_MSO72004C, 'ACQuire:NUMACq?')); % 完成一次完整采集（无波形平均）
            while str2double(query(interfaceObj_MSO72004C, 'ACQuire:NUMACq?')) == ACQnum
            end
            fprintf(interfaceObj_MSO72004C, 'ACQuire:STATE OFF'); % 停止采集
            
            disp(['采集数据:',num2str(toc),'秒'])
            pause(1);
            tic
            %% 波形数据处理
            HorLen = str2double(query(interfaceObj_MSO72004C, 'HORizontal:RECOrdlength?')); % 获取示波器的记录点数
            Len = min(HorLen, RecordLen); % 实际数据长度
            HeaderLen = floor(log10(Len)) + 3; % 数据块头长度，用于指示数据长度的冗余数据，例如长5000，头为'#45000'，4表示5000的位数
            WfmData = zeros(Len, ChanNum); % 波形数据
            
            for m = 1:ChanNum
                fprintf(interfaceObj_MSO72004C, ['DATa:SOUrce CH', num2str(EffChan(m))]); % 选中打开的通道
                yMult = str2double(query(interfaceObj_MSO72004C, 'WFMOutpre:YMUlt?')); % 波形每量化单位电平放大系数
                yOff = str2double(query(interfaceObj_MSO72004C, 'WFMOutpre:YOFf?')); % 波形位置，量化单位
                yZero = str2double(query(interfaceObj_MSO72004C, 'WFMOutpre:YZEro?')); % 波形纵向偏置，V
                
                fprintf(interfaceObj_MSO72004C, ['DATA:SOUR CH' num2str(EffChan(m)) ';START ' num2str(1) ';STOP ' num2str(HorLen)]); % 设定输出波形数据参数
                fprintf(interfaceObj_MSO72004C, 'CURVE?'); % 请求波形数据
                fscanf(interfaceObj_MSO72004C, '%c', HeaderLen); % 读取数据头，并抛弃
                [data, ~] = fread(interfaceObj_MSO72004C, Len, 'int8'); % 读取数据头后的真实数据
                
                WfmData(:, m) = yMult * (data - yOff) - yZero; % 返回电平数据
            end
            disp(['波形数据处理:',num2str(toc),'秒'])
        end
        
        function close(obj)
            fclose(obj.interface);
            % fprintf(obj.interface, 'ACQUIRE:STATE STOP');
            flushinput(obj.interface);
            flushoutput(obj.interface);
            fclose(obj.interface);
        end
    end
end
