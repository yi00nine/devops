前景提要:公司有一个老项目需要嵌入到别人的系统中,甲方要求请求的地址加上他们系统的前缀,如之前访问的地址是 127.0.0.1/home 需要变成 127.0.0.1/system/v1/home

#### 打包配置 publicPath

在 webpack 或者 vite 的配置文件中修改 publicPath 为/system/v1,重新进行打包,这个时候 index.html 文件里面加载的静态资源就会加上 publicPath 路径

#### 配置 nginx

```
server {
        listen       8384;
        listen       [::]:8384;
        server_name  webroot;
        root   /usr/share/nginx/html/;

        include /etc/nginx/default.d/*.conf;
        location /system/v1/{
          alias   /usr/share/nginx/html/;
          try_files $uri $uri/ /system/v1/index.html;
          index  index.html index.htm;
        }
        location /{
          try_files $uri $uri/ /index.html;
          index  index.html index.htm;
        }

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }

```

#### 踩坑 1

前端服务是通过 docker 容器启动的,8384 端口映射到主机的 8080 端口,访问主机的 8080 端口加配置的路径一直是 404,最后排查发现是本机的 8080 端口被本机的 nginx 监听了,所以之前访问的一直是本机的 nginx 服务,不是容器内的

#### 踩坑 2

在 nginx.conf 里面配置 root 目录不生效,返回 500.需要在 location 里面配置 alias

设置 root 为/usr/share/nginx/html/,nginx 匹配到/system/v1 路径会去 /usr/share/nginx/html/system/v1 去找静态资源,因此返回 500

需要设置 alias 解决,当 Nginx 接收到一个请求时，它会将请求的 URI 与 `location` 块中的 `alias` 指令指定的路径进行匹配，并使用匹配的路径来确定实际的文件路径。与 `root` 不同，`alias` 指令会将匹配的部分替换为指定的路径
