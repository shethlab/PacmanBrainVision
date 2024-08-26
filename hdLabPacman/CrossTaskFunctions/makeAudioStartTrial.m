function [sf,STSound] = makeAudioStartTrial(sf)
% Function generates a single beep tone for trials count.
% Assia Chericoni 08/29/2023
%
%
% Ouputs:
%   1) sf: sampling frequency of tone
%   2) StartTrialSound: single beep tone to mark Trial Start

if nargin < 1
        sf = 22050; % sample frequency (Hz)  
end

% Set sound parameters
d = 0.1;                      % duration - each tone (s)
n = sf * d;                   % number of samples
stmp = (1:n) / sf;            % sound data preparation

beepFrequency = 1320;   % Frequency of the beep tone

s = sin(2 * pi * beepFrequency * stmp); % Sinusoidal waveform for the beep tone
STSound = s; % start trial sound 
 
end