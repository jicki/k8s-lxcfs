FROM ubuntu:18.04 as build
RUN apt update -y
RUN apt-get --purge remove lxcfs
RUN apt install -y wget git libtool m4 autotools-dev automake pkg-config build-essential libfuse-dev libcurl4-openssl-dev libxml2-dev mime-support
ENV LXCFS_VERSION 4.0.12

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
