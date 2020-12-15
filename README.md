# k8s-lxcfs
kubernetes-lxcfs



## 绑定这里提到了是在 openbayes 的构建流程中做了修改：

```yaml

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

```
