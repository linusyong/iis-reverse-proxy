FROM    microsoft/iis
 
RUN     mkdir c:\temp
 
COPY    requestRouter_amd64.msi c:/temp/
COPY    rewrite_amd64.msi c:/temp/
 
 
RUN     msiexec.exe /i "c:\temp\requestRouter_amd64.msi" /qn
RUN     msiexec.exe /i "c:\temp\rewrite_amd64.msi" /qn
 
RUN     powershell -NoProfile -Command \
        Remove-Item c:\temp -Recurse -Force
 
RUN     powershell -NoProfile -Command \
        Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Name 'enabled' -Filter 'system.webServer/proxy' -Value 'True'
