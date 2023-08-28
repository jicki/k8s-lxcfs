# k8s-lxcfs

* `https://github.com/lxc/lxcfs`

---

* lxcfs 提供了信息

  * 如: /proc/uptime 会反映 `容器` 实际的运行时间, 而不是 `node` 主机的运行时间。

```
/proc/cpuinfo
/proc/diskstats
/proc/loadavg
/proc/meminfo
/proc/stat
/proc/swaps
/proc/uptime
/sys/devices/system/cpu/online

```


# 安装 lxcfs

* 容器中使用 lxcfs 需要在每个 node 主机都安装并启动 lxcfs.

---

* centos

```
yum install fuse fuse-lib fuse-devel
git clone https://github.com/lxc/lxcfs
cd lxcfs
./bootstrap.sh
./configure
make
make install

```

---

* 启动 lxcfs

```
sudo mkdir -p /var/lib/lxcfs
sudo lxcfs /var/lib/lxcfs
```

---

* 选择 systemctl 方式运行

```
cat > /usr/lib/systemd/system/lxcfs.service <<EOF
[Unit]
Description=lxcfs

[Service]
ExecStart=/usr/bin/lxcfs -f /var/lib/lxcfs
Restart=on-failure
#ExecReload=/bin/kill -s SIGHUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

```

```
systemctl daemon-reload
systemctl start lxcfs
systemctl status lxcfs

```


## Docker 中使用 lxcfs

* 请使用非 alpine 镜像, alpine 镜像挂载会出现问题

```
docker run -it -m 256m --memory-swap 256m \
      -v /var/lib/lxcfs/proc/cpuinfo:/proc/cpuinfo:rw \
      -v /var/lib/lxcfs/proc/diskstats:/proc/diskstats:rw \
      -v /var/lib/lxcfs/proc/meminfo:/proc/meminfo:rw \
      -v /var/lib/lxcfs/proc/stat:/proc/stat:rw \
      -v /var/lib/lxcfs/proc/loadavg:/proc/loadavg:rw \
      -v /var/lib/lxcfs/proc/swaps:/proc/swaps:rw \
      -v /var/lib/lxcfs/proc/uptime:/proc/uptime:rw \
      -v /var/lib/lxcfs/proc/slabinfo:/proc/slabinfo:rw \
      ubuntu:18.04 /bin/bash
```



## Kubernetes 中使用 lxcfs



### 构建新的 lxcfs 容器


* dockerfile

```

FROM ubuntu:18.04 as build
RUN apt update -y
RUN apt-get --purge remove lxcfs
RUN apt install -y wget git libtool m4 autotools-dev automake pkg-config build-essential libfuse-dev libcurl4-openssl-dev libxml2-dev mime-support
ENV LXCFS_VERSION 4.0.6

RUN wget https://github.com/lxc/lxcfs/archive/lxcfs-$LXCFS_VERSION.tar.gz && \
    mkdir /lxcfs && tar xzvf lxcfs-$LXCFS_VERSION.tar.gz -C /lxcfs --strip-components=1 && \
    cd /lxcfs  && ./bootstrap.sh && ./configure && make

FROM ubuntu:18.04
STOPSIGNAL SIGINT
COPY --from=build /lxcfs/src/lxcfs /usr/local/bin/lxcfs
COPY --from=build /lxcfs/src/.libs/liblxcfs.so /usr/local/lib/lxcfs/liblxcfs.so
COPY --from=build /lxcfs/src/liblxcfs.la /usr/local/lib/lxcfs/liblxcfs.la
COPY --from=build /lxcfs/src/lxcfs /lxcfs/lxcfs
COPY --from=build /lxcfs/src/.libs/liblxcfs.so /lxcfs/liblxcfs.so
COPY --from=build /lxcfs/src/liblxcfs.la /lxcfs/liblxcfs.la
COPY --from=build /lib/x86_64-linux-gnu/libfuse.so.2.9.7 /usr/lib64/libfuse.so.2.9.7
COPY --from=build /lib/x86_64-linux-gnu/libulockmgr.so.1.0.1 /usr/lib64/libulockmgr.so.1.0.1
RUN ln -s /usr/lib64/libfuse.so.2.9.7 /usr/lib64/libfuse.so.2 && \
    ln -s /usr/lib64/libulockmgr.so.1.0.1 /usr/lib64/libulockmgr.so.1

COPY start.sh /
RUN chmod +x /start.sh
CMD ["/start.sh"]


```

---

* start.sh 


```
#!/bin/bash

# Cleanup
nsenter -m/proc/1/ns/mnt fusermount -u /var/lib/lxcfs 2> /dev/null || true
nsenter -m/proc/1/ns/mnt [ -L /etc/mtab ] || \
        sed -i "/^lxcfs \/var\/lib\/lxcfs fuse.lxcfs/d" /etc/mtab

# Prepare
mkdir -p /usr/local/lib/lxcfs /var/lib/lxcfs

# Update lxcfs
cp -f /lxcfs/lxcfs /usr/local/bin/lxcfs
cp -f /lxcfs/liblxcfs.so /usr/local/lib/lxcfs/liblxcfs.so
cp -f /lxcfs/liblxcfs.la /usr/local/lib/lxcfs/liblxcfs.la


# Mount
exec nsenter -m/proc/1/ns/mnt /usr/local/bin/lxcfs /var/lib/lxcfs/ --enable-cfs -l
```











### Kubernetes 部署 lxcfs

* 在 k8s 中使用 lxcfs 比较麻烦 需要在每个 k8s 节点都部署一个 `lxcfs` 服务.

---

* k8s 节点使用 daemonset 部署就可以

```
kubectl apply -f lxcfs-daemonset.yaml

```


### 绑定这里提到了是在 openbayes 的构建流程中做了修改：

  * `"initializer.kubernetes.io/lxcfs": "true"`  initializer 在 k8s 1.14 之后被废弃. 所以不能自动注入挂载

---

* 因为没有自动注入所以需要手动配置挂载资源

  * 不要使用 alpine 镜像, 挂载有问题


```yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: web
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: httpd:2.4.32
          resources:
            requests:
              memory: "2Gi"
              cpu: "2000m"
            limits:
              memory: "2Gi"
              cpu: "2000m"
        # 配置探针在遇到  Transport endpoint is not connected 自动重启
          livenessProbe:
            exec:
              command:
              - sh
              - -c
              - |
                cat /proc/loadavg &&
                cat /proc/cpuinfo
            initialDelaySeconds: 5
            periodSeconds: 5        
	# volumeMounts lxcfs 
          volumeMounts:
            - name: lxcfs-proc-cpuinfo
              mountPath: /proc/cpuinfo
            - name: system-cpu-online
              mountPath: /sys/devices/system/cpu/online
            - name: lxcfs-proc-meminfo
              mountPath: /proc/meminfo
            - name: lxcfs-proc-diskstats
              mountPath: /proc/diskstats
            - name: lxcfs-proc-stat
              mountPath: /proc/stat
            - name: lxcfs-proc-swaps
              mountPath: /proc/swaps
            - name: lxcfs-proc-uptime
              mountPath: /proc/uptime
            - name: lxcfs-proc-loadavg
              mountPath: /proc/loadavg
      # volumes lxcfs
      volumes:
        - name: lxcfs-proc-cpuinfo
          hostPath:
            path: /var/lib/lxcfs/proc/cpuinfo
            type: File
        - name: system-cpu-online
          hostPath:
            path: /var/lib/lxcfs/sys/devices/system/cpu/online
            type: File
        - name: lxcfs-proc-diskstats
          hostPath:
            path: /var/lib/lxcfs/proc/diskstats
            type: File
        - name: lxcfs-proc-meminfo
          hostPath:
            path: /var/lib/lxcfs/proc/meminfo
            type: File 
        - name: lxcfs-proc-stat
          hostPath:
            path: /var/lib/lxcfs/proc/stat
            type: File    
        - name: lxcfs-proc-swaps
          hostPath:
            path: /var/lib/lxcfs/proc/swaps
            type: File
        - name: lxcfs-proc-uptime
          hostPath:
            path: /var/lib/lxcfs/proc/uptime
            type: File   
        - name: lxcfs-proc-loadavg
          hostPath:
            path: /var/lib/lxcfs/proc/loadavg
            type: File         
```



### 测试


* free 内存


```
kubectl exec web-fb779ff47-wts5l free
             total       used       free     shared    buffers     cached
Mem:       2097152      10508    2086644        264          0        264
-/+ buffers/cache:      10244    2086908
Swap:            0          0          0


```

---

* top cpu


```

top - 02:59:50 up 3 min,  0 users,  load average: 0.48, 0.94, 1.10
Tasks:   6 total,   1 running,   5 sleeping,   0 stopped,   0 zombie
%Cpu0  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem:   2097152 total,    12068 used,  2085084 free,        0 buffers
KiB Swap:        0 total,        0 used,        0 free.      264 cached Mem

   PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND                                                                                                        
     1 root      20   0   79292   4316   3524 S   0.0  0.2   0:00.05 httpd                                                                                                          
     7 daemon    20   0  368472   3524   2404 S   0.0  0.2   0:00.00 httpd                                                                                                          
     8 daemon    20   0  368472   3524   2404 S   0.0  0.2   0:00.00 httpd                                                                                                          
     9 daemon    20   0  368472   3524   2404 S   0.0  0.2   0:00.00 httpd                                                                                                          
   115 root      20   0   20264   3244   2740 S   0.0  0.2   0:00.00 bash                                                                                                           
   122 root      20   0   21948   2448   2092 R   0.0  0.1   0:00.00 top

```


---


