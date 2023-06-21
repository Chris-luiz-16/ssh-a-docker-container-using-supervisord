FROM httpd:alpine
 
ENV HOME_DIR /usr/local/apache2/
 
ENV USER chris
 
WORKDIR $HOME_DIR
 
RUN adduser -h $HOME_DIR -s /bin/sh -u 1005 -D chris
 
COPY ./public_html htdocs/
 
RUN mkdir .ssh/
 
COPY ./chrisops.pub  .ssh/authorized_keys
 
RUN apk update && apk add supervisor openssh --no-cache
 
RUN ssh-keygen -A
 
RUN mv /usr/sbin/sshd /usr/bin/sshd
 
RUN cp /etc/ssh/ssh_host* .
 
RUN sed -i 's+#HostKey /etc/ssh/+HostKey /usr/local/apache2/+g' /etc/ssh/sshd_config
 
RUN chown -R $USER. $HOME_DIR
 
COPY ./supervisor.conf .
 
EXPOSE 22 80
 
USER $USER
 
ENTRYPOINT ["/usr/bin/supervisord"]
 
CMD ["-c","supervisor.conf"]
