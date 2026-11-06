function saveFigureFile(saveFcn, fileName)
% SAVEFIGUREFILE  Run one save command, and try again if Windows refuses.
%
% OneDrive locks a file for a moment while it syncs it, and Windows will not
% overwrite a file that is open in a viewer. Both look like
% "Could not open file" / "PNG library failed". Waiting a second and trying
% again usually works. After 3 attempts we stop with a message that says
% which file failed and what to check.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
    for attempt = 1:3
        try
            saveFcn();
            return
        catch ME
            if attempt == 3
                error('Could not save %s after 3 attempts (%s).\nCheck that the file is not open, that the results folder is not syncing (OneDrive), and that the path is shorter than 260 characters.', ...
                    fileName, ME.message);
            end
            pause(1);
        end
    end
end

