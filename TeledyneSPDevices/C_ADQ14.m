% ADQ14接口函数
classdef C_ADQ14
    properties
        interface = 0;
        boardid = 1;
        nRecords = 1;
        nSamples = 10000;
        mode_trigger = 0;
        mode_ref = 0;
        nSkip = 1;
        analogbias = 0;
        nChannel = 1;
        ChannelsMask = 1;
        nRecords_raw =1;
    end
    methods
        function obj = C_ADQ14()
            addpath('./ADQ14_MATLAB');
            define_command_codes;
            obj.mode_trigger = SW_TRIGGER_MODE;
            % obj.mode_trigger = INTERNAL_TRIGGER_MODE;
            obj.mode_ref = EXT; % ? 外部采样信号 EXT 内部采样内部时钟INT_INTREF
        end
        
        function obj = connect(obj)
            obj.nChannel= double(interface_ADQ('getnofchannels',[],obj.boardid));
            disp(['NChannel:', num2str(obj.nChannel)]);
            % ! 设置软件触发和外部参考
            % switch obj.mode_trigger
            % case SW_TRIGGER_MODE
            disp('软件触发模式');
            disp(['Set Trig Mode:', num2str(interface_ADQ('settriggermode',obj.mode_trigger,obj.boardid))]);
            % case INTERNAL_TRIGGER_MODE
            %     disp('内部触发模式');
            %     %! 等待时间100ms
            
            %     cycleNum = floor(100e-3*1e9);
            %     disp(['Set Trig Mode:', num2str(interface_ADQ('settriggermode',obj.mode_trigger,obj.boardid))]);
            %     disp(['Set Trig Cycle:', num2str(interface_ADQ('set_internal_trigger_period',obj.mode_trigger,obj.boardid))]);
            % end
            
            disp(['Set Ref Mode:', num2str(interface_ADQ('set_clock_source', obj.mode_ref,obj.boardid))]);
            if(obj.nChannel>0)
                disp(['Set DBS Setup:',...
                    num2str(interface_ADQ('setadjustablebias', [1 obj.analogbias], obj.boardid))]);
            else
                error('获取通道数小于1');
            end
        end
        
        function obj = setMultiMode(obj, nRecords, nSamples)
            obj.nRecords = nRecords;
            obj.nSamples = nSamples;
            disp(['Set Multi Record Setup:', ...
                num2str(interface_ADQ('multi_record_setup', [obj.nRecords, obj.nSamples],obj.boardid))]);
            
            disp(['Set MultiRecord Channel Mask:', ...
                num2str(interface_ADQ('multirecordsetchannelmask', 1, obj.boardid))])
        end
        
        function obj = setMultiMode_ExtTrigger(obj, nRecords, nSamples)
            disp(['Set Trig Mode:', num2str(interface_ADQ('settriggermode', 2, obj.boardid))]);
            disp(['Set Trig Mode Edge:', num2str(interface_ADQ('settriggeredge', [2, 1], obj.boardid))]);
            
            obj.nRecords = nRecords;
            obj.nSamples = nSamples;
            disp(['Set Multi Record Setup:', ...
                num2str(interface_ADQ('multi_record_setup', [obj.nRecords, obj.nSamples],obj.boardid))]);
            
            disp(['Set MultiRecord Channel Mask:', ...
                num2str(interface_ADQ('multirecordsetchannelmask', 1, obj.boardid))])
        end
        
        
        function closeMultiMode(obj)
            interface_ADQ('disarmtrigger', [] ,obj.boardid);
            interface_ADQ('multirecordclose', [], obj.boardid);
            clear mex;
            disp('Close Multi Mode!!!!!');
        end
        function obj = setRawStreamMode(obj)
            disp('Set Transfer Buffer');
            nBuffers = 192;
            sizeBuffer = 1024*1024*8;
            disp(['nBuffer:', num2str(nBuffers), '; sizeBuffer(MB):', num2str(sizeBuffer/2^20)]);
            disp(interface_ADQ('settransferbuffers', [nBuffers, sizeBuffer], obj.boardid));
            disp(['Set Stream Statue:', ...
                num2str(interface_ADQ('set_stream_status', 1, obj.boardid))]);
            
            disp(['Stop Streaming:', ...
                num2str(interface_ADQ('stopstreaming', [], obj.boardid))]);
            disp('-----------Starting Acquisition---------');
            
            obj.nRecords_raw = 1e9;
            flush_timeout = 2;
            dataA = zeros(obj.nRecords_raw, 1, 'int16');
            
            disp(['Arm Trigger:',...
                num2str(interface_ADQ('armtrigger',[],obj.boardid))]);
            
            disp(['Start Streaming', ...
                num2str(interface_ADQ('StartStreaming', [], obj.boardid))]);
            
            disp(['swtrig:',...
                num2str(interface_ADQ('swtrig',[],obj.boardid))]);
            
            starttime = clock;
            flush_clock = clock;
            nRecord_total = 0;
            while (nRecord_total<obj.nRecords_raw)
                buffer_filled = 0;
                while(buffer_filled==0)
                    buffer_filled = interface_ADQ('gettransferbufferstatus', [], obj.boardid);
                end
                if(interface_ADQ('getstreamoverflow', [], obj.boardid))
                    error('内存溢出');
                end
                samples_in_buffer = min(interface_ADQ('getsamplesperpage', [], obj.boardid));
                
                collect_result = interface_ADQ('collectdatanextpage', [], obj.boardid);
                
                
                nRecord_new = size(data.DataA, 2);
                t1 = clock;
                flush_diff = etime(t1, flush_clock);
                if nRecord_new> 0
                    flush_clock = clock;
                    % Note: Printouts consume considerable amount of time!
                    %fprintf('Records completed this round: Ch A=%d,Ch B=%d,Ch C=%d,Ch D=%d\n', nof_records_now);
                    %fprintf('Records completed in total:   A=%d,B=%d,C=%d,D=%d\n', nof_records_tot);
                    dataA(nRecord_total+(1:nRecord_new)) = data.DataA;
                    % Store data
                    %for r = 1:nof_records_now(1)
                    %  dataA(:, nof_records_tot(1) + r) = data.DataA(:, r);
                    %end
                elseif flush_diff > flush_timeout
                    % Flush the DMA engine.
                    fprintf('Flush timeout after %d seconds\n',flush_diff);
                    status = interface_ADQ('flushdma', obj.boardid);
                    if status == 0
                        error('Failed to flush DMA transfer');
                    end
                    flush_clock = clock;
                end
                
                nRecord_total = nRecord_total + nRecord_new;
            end
            fprintf('---------------------------------------------------\n');
        end
        function closeRawStreamMode(obj)
            interface_ADQ('StopStreaming', [], obj.boardid);
            interface_ADQ('disarmtrigger', [], obj.boardid);
            clear mex;
            disp('Close RawStream Mode!!!!!');
        end
        
        function outData = oneMultiMode(obj)
            disp(['DisArm Trigger:', ...
                num2str(interface_ADQ('disarmtrigger',[],obj.boardid))]);
            disp(['Arm Trigger:',...
                num2str(interface_ADQ('armtrigger',[],obj.boardid))]);
            
            for iL = 1:obj.nRecords
                disp(['swtrig:',...
                    num2str(interface_ADQ('swtrig',[],obj.boardid))]);
            end
            % Wait for all records to be triggered
            acquired = 0;
            acquiredold = 0;
            tic;
            fprintf('Waiting for triggers...\n');
            while (acquired < obj.nRecords)
                acquired = interface_ADQ('getacquiredrecords',[],obj.boardid);
                if acquired ~= acquiredold
                    fprintf('Acquired %d of %d records. (%.2f seconds)\n', acquired, obj.nRecords, toc);
                    acquiredold = acquired;
                end
            end
            % Retrieve data
            target_buffer_size = obj.nRecords*obj.nSamples;
            target_bytes_per_sample = 2;
            StartRecordNumber = 0;
            StartSample = 0;
            % obj.nSamples = nofsamples;
            obj.ChannelsMask  = 1;
            [gdata, ~, status, d] = interface_ADQ('getdata', ...
                [target_buffer_size
                target_bytes_per_sample
                StartRecordNumber
                obj.nRecords;
                obj.ChannelsMask
                StartSample
                obj.nSamples], ...
                obj.boardid);
            outData = reshape(gdata.DataA, numel(gdata.DataA),[]);
        end
        function outData = oneMultiMode_ExtTrigger(obj)
            disp(['DisArm Trigger:', ...
                num2str(interface_ADQ('disarmtrigger',[],obj.boardid))]);
            disp(['Arm Trigger:',...
                num2str(interface_ADQ('armtrigger',[],obj.boardid))]);
            
            %             for iL = 1:obj.nRecords
            %                             disp(['swtrig:',...
            %                 num2str(interface_ADQ('swtrig',[],obj.boardid))]);
            %             end
            % Wait for all records to be triggered
            acquired = 0;
            acquiredold = 0;
            tic;
            fprintf('Waiting for triggers...\n');
            while (acquired < obj.nRecords)
                acquired = interface_ADQ('getacquiredrecords',[],obj.boardid);
                if acquired ~= acquiredold
                    fprintf('Acquired %d of %d records. (%.2f seconds)\n', acquired, obj.nRecords, toc);
                    acquiredold = acquired;
                end
            end
            % Retrieve data
            target_buffer_size = obj.nRecords*obj.nSamples;
            target_bytes_per_sample = 2;
            StartRecordNumber = 0;
            StartSample = 0;
            % obj.nSamples = nofsamples;
            obj.ChannelsMask  = 1;
            [gdata, ~, status, d] = interface_ADQ('getdata', ...
                [target_buffer_size
                target_bytes_per_sample
                StartRecordNumber
                obj.nRecords;
                obj.ChannelsMask
                StartSample
                obj.nSamples], ...
                obj.boardid);
            outData = reshape(gdata.DataA, numel(gdata.DataA),[]);
        end
        function preArmTrig(obj)  %! 预触发模式
            
        end
        function outData = progMultiMode(obj, waitTime)
            disp(['DisArm Trigger:', ...
                num2str(interface_ADQ('disarmtrigger',[],obj.boardid))]);
            disp(['Arm Trigger:',...
                num2str(interface_ADQ('armtrigger',[],obj.boardid))]);
            for iL = 1:obj.nRecords
                pause(waitTime(iL)); %! 暂停这些时间后触发
                disp(['swtrig:',...
                    num2str(interface_ADQ('swtrig',[],obj.boardid))]);
            end
            % Wait for all records to be triggered
            acquired = 0;
            acquiredold = 0;
            tic;
            fprintf('Waiting for triggers...\n');
            while (acquired < obj.nRecords)
                acquired = interface_ADQ('getacquiredrecords',[],obj.boardid);
                if acquired ~= acquiredold
                    fprintf('Acquired %d of %d records. (%.2f seconds)\n', acquired, obj.nRecords, toc);
                    acquiredold = acquired;
                end
            end
            % Retrieve data
            target_buffer_size = obj.nRecords*obj.nSamples;
            target_bytes_per_sample = 2;
            StartRecordNumber = 0;
            StartSample = 0;
            % obj.nSamples = nofsamples;
            obj.ChannelsMask  = 1;
            [gdata, ~, status, d] = interface_ADQ('getdata', ...
                [target_buffer_size
                target_bytes_per_sample
                StartRecordNumber
                obj.nRecords;
                obj.ChannelsMask
                StartSample
                obj.nSamples], ...
                obj.boardid);
            outData = reshape(gdata.DataA, numel(gdata.DataA),[]);
        end
    end
end
