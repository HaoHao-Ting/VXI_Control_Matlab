% add a demo to show how to control the signal source of Keysight
addpath('Keysight'); % tell MATLAB where to find the function files

ipAddress  = '192.158.1.1';
obj_Source = C_KeysightSignalSource(ipAddress);
obj_Source.setFre(1e9);  % set the fequency into 1GHz
obj_Source.on();  % Open the ouput of the signal source


obj_Source.close(); % Better to close the interface of object at last;

