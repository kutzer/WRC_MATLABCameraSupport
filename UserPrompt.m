function UserPrompt(msg,ttl,icon)

h = msgbox(msg,ttl, 'custom', icon);
th = findall(h, 'Type', 'Text');        % Get handle to text within msgbox
th.FontSize = 12;                       % Change the font size
drawnow;

uiwait(h);
