# IIS Reverse Proxy on Windows Server Core Docker Container

## Introduction
When using the Container Platform to deploy IIS, it is sometime difficult to configure the IIS service as there's no GUI for configuration.  This page documents down how to setup IIS with Reverse Proxy and Rewrite capability.

## IIS Rewrite Module
IIS Rewrite module need to be installed for IIS to be able to perform rule-based rewrite/redirect.  For example, of you want all http to be redirected to https or you have moved your wwwroot directory into a subdirectory.  [Microsoft IIS Rewrite module website](https://www.iis.net/downloads/microsoft/url-rewrite) has a better explanation on the capability.

IIS Rewrite is good for working within a single IIS site, but it does not allow "Reverse Proxy" to another site.  For example if the URL https://www.e-solex.com/hello should be served from http://<another-web-site>:8080/, IIS Rewrite module alone won't work.

Another use of Reverse Proxy can be for SSL offloading.

## IIS Application Request Routing (ARR)
To allow "Reverse Proxy", IIS need the ARR module.  Microsoft ARR website can be found [here](https://www.iis.net/downloads/microsoft/application-request-routing).  On the website, it is sated that WebFarm Framework is needed for ARR.  However, with IIS 10 on Windows Server Core, it doesn't seem to need WebFarm Framework.

## IIS Reverse Proxy Docker Image
A Container image can be created specifically to perform some reverse proxy task.  However, it is also good to create a generic Docker image.  To create a generic IIS reverse proxy Docker image:
1.  Download IIS Rewrite Module and IIS AAR Module from:
    1.  http://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi
    1.  http://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi

1.  Build a Docker image using the following the Dockerfile in the repository

## Using IIS reverse proxy Docker Image
Once the image is build according to the previous section, a container with IIS Reverse Proxy can be started using the command (assuming that the image created is call `iis-proxy`):

`docker run -it -d --rm --name iis-proxy-test -p 80:80 iis-proxy`

Once the container is running, the Default Web Site should be accessible on port 80.  Once a web.config is created for the site ([Microsoft example and explanation of ARR proxy rewriting](https://docs.microsoft.com/en-us/iis/extensions/url-rewrite-module/reverse-proxy-with-url-rewrite-v2-and-application-request-routing#configuring-rules-for-the-reverse-proxy)), it will be able to perform proxy rewriting.

Another way is to build on top of this Docker image to create an application specific Docker image.

### Building Application Specific Docker Image
In this example, we will use the reverse proxy of IIS to rewrite all content from the Default Web Site url which contain `http://<server>/hello/<*>` to be proxied from `http://<server>:8080/`.

1.  Create a Dockerfile
    ```
    FROM    iis-proxy
     
     
    RUN     powershell -NoProfile -Command \
            New-Item c:\sites\helloworld -type directory
     
    RUN     powershell -NoProfile -Command \
            echo "Hello World" > c:\sites\helloworld\index.html; \
            New-IISSite -Name "HelloWorld" -BindingInformation "*:8080:" -PhysicalPath "c:\sites\helloworld"
     
    COPY    web.config 'C:\inetpub\wwwroot\'
     
    EXPOSE  80 8080
     
    CMD     [ "powershell" ]
    ```

1.  Create a web.config
    ```
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
      <system.webServer>
        <rewrite>
          <rules>
            <rule name="Proxy" stopProcessing="true">
              <match url="^hello/(.*)" />
              <action type="Rewrite" url="http://localhost:8080/{R:1}" appendQueryString="false" />
            </rule>
          </rules>
        </rewrite>
      </system.webServer>
    </configuration>
    ```
    It is also possible to use powershell to generate the configuration rather than creating web.config file (replace the `COPY    web.config 'C:\inetpub\wwwroot\'` line with the following):
    ```
    RUN   powershell -NoProfile -Command \
            Start-Job -Name AddWebConfig -ScriptBlock { \
              Add-WebConfigurationProperty -pspath 'iis:\sites\Default' -filter 'system.webServer/rewrite/rules' -name '.' -value @{name='Proxy';stopProcessing='True'}; \
            }; \
            Wait-Job -Name AddWebConfig; \
          Set-WebConfigurationProperty -pspath 'iis:\sites\Default' -filter 'system.webServer/rewrite/rules/rule/match' -name 'url' -value '^^hello/(.*)'; \
          Set-WebConfigurationProperty -pspath 'iis:\sites\Default' -filter 'system.webServer/rewrite/rules/rule/action' -name 'type' -value 'Rewrite'; \
          Set-WebConfigurationProperty -pspath 'iis:\sites\Default' -filter 'system.webServer/rewrite/rules/rule/action' -name 'url' -value 'http://localhost:8080/{R:1}'

    ``` 

1.  Build the image using the command `docker build -t hello-world-proxy .` in the directory that contain both files and run it using the command:
    ```
    docker run -it -d -p 80:80 -p 8080:8080 --name hello-world --rm hello-world-proxy
    ```

1.  Accessing the URL http://&lt;server&gt;/hello/ should display "Hello World" which is proxied from http://&lt;server&gt;:8080/.
