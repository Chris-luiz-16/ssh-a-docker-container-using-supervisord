# ssh-a-docker-container-using-supervisord
This GitHub repository contains a Dockerfile for creating a secure Docker container that enables SSH access, runs an Apache HTTP server, and utilizes Supervisor for enhanced process management. The primary focus of this repository is to showcase the prevention of container breakout by running the container in a non-root user, while also leveraging Supervisor to effectively manage multiple processes.

Container breakout refers to the security vulnerability where an attacker gains unauthorized access to the host system from within a container. By default, Docker containers run with root privileges, which can be exploited to compromise the underlying host.

To mitigate this risk, this Dockerfile incorporates several security measures. It begins by creating a non-root user named "chris" inside the container using the adduser command. This user is assigned a specific home directory, reducing the potential impact of a container breakout as the attacker would not have root privileges on the host system.

Furthermore, the Dockerfile leverages passwordless authentication to enable SSH access without requiring a password. The public key, contained in the chrisops.pub file, is copied to the .ssh/authorized_keys file inside the container. This allows the designated user "chris" to securely authenticate using their private key without the need for a password.

Additionally, this Dockerfile includes the utilization of Supervisor, a process control system, to manage multiple processes within the container. The supervisor.conf file, also included in the container, specifies the processes to be supervised by Supervisor. This ensures the reliable execution and monitoring of critical processes, such as the Apache HTTP server and SSH daemon, within the container.

By combining the utilization of a non-root user, passwordless authentication, and Supervisor, this Docker container enhances security and process management capabilities. Running the container with a non-root user significantly reduces the risk of container breakout, while passwordless authentication streamlines the authentication process. Moreover, Supervisor ensures the reliable execution and monitoring of multiple processes within the container, contributing to a secure and well-managed containerized environment.


## Table of contents
* [Prerequisites](#prerequisites)
  * [Docker installation on your server](#docker-installation-on-your-server)
  * [Passwordless authentication for the ssh user](#passwordless-authentication-for-the-ssh-user)
  * [Copying files to the container](#copying-files-to-the-container)
* [Dockerfile Breakout](#dockerfile-breakout)
* [Final output](#final-output)


## Prerequisites

### Docker installation on your server
You can install Docker by following the official doc [Docker install on various OS](https://docs.docker.com/engine/install/). In my case, I'm using amazon linux 2023. I've installed it by using the following method
```sh
sudo yum install docker git -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
sudo su - ec2-user
```
If everything looks good it should show the below output when executing ```docker version``` command
```
$ docker version
Client:
 Version:           20.10.23
 API version:       1.41
 Go version:        go1.19.8
 Git commit:        7155243
 Built:             Mon May  1 21:07:11 2023
 OS/Arch:           linux/amd64
 Context:           default
 Experimental:      true

Server:
 Engine:
  Version:          20.10.23
  API version:      1.41 (minimum version 1.12)
  Go version:       go1.19.8
  Git commit:       6051f14
  Built:            Wed Apr 19 00:00:00 2023
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.6.19
  GitCommit:        1e1ea6e986c6c86565bc33d52e34b81b3e2bc71f
 runc:
  Version:          1.1.5
  GitCommit:        f19387a6bec4944c770f7668ab51c4348d9c2f38
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```
### Passwordless authentication for the ssh user

Run the command ```ssh-keygen``` in your server. An example for the same is attached below
```sh
[ec2-user@ip-172-31-1-125 ~]$ ssh-keygen
Generating public/private rsa key pair.
# You can enter any name you want, but make sure you edit the same in the dockerfile
Enter file in which to save the key (/home/ec2-user/.ssh/id_rsa): chrisops 
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in chrisops
Your public key has been saved in chrisops.pub
The key fingerprint is:
SHA256:j4aCJQWAjMG1Qo1lVoOjldhYw3+opSM6qSQMfQ+CtJU ec2-user@ip-172-31-1-125.ap-south-1.compute.internal
The key's randomart image is:
+---[RSA 3072]----+
|B+%B+o           |
|+*oX+ .          |
| ooE+ .          |
|.++. + .         |
|o.+ B . S        |
|o. X o . o       |
|o+o o o o .      |
|*    . .         |
|o.               |
+----[SHA256]-----+
```
You can enter any name you want for the ssh files to be stored but make sure you edit the same in the Dockerfile in ***line 15***
### Copying files to the container
I've used the ***public_html*** directory to copy the files to the container, make sure you move the contents to public_html so that they can be copied to the container
```sh
git clone https://github.com/Chris-luiz-16/ssh-a-docker-container-using-supervisord.git website
mv <website contents dir>/* website/public_html/
```
I've used the below supervisor configuration in supervisor.conf file. You can add other programs depending on your needs and build the image accordingly
```sh
[supervisord]
nodaemon=true


[program:sshd]
command=/usr/bin/sshd -D

[program:httpd]
command=httpd-foreground
```

## Dockerfile Breakout

The container is based on the httpd:alpine image and provides an Apache HTTP server. Here's a description of the Dockerfile's contents:

```sh
# The Dockerfile begins with the following base image:
FROM httpd:alpine

# Sets the environment variables HOME_DIR and USER:
ENV HOME_DIR /usr/local/apache2/

ENV USER chris

# The working directory of the image is set by calling the ENV variable:
WORKDIR $HOME_DIR

# A user named "chris" is added to the container with a home directory called from the ENV variable:
RUN adduser -h $HOME_DIR -s /bin/sh -u 1005 -D chris

# The contents of the ./public_html directory are copied to htdocs/ inside the container:
COPY ./public_html htdocs/

# A .ssh/ directory is created inside the working directory of the container:
RUN mkdir .ssh/

# The chrisops.pub file is copied to .ssh/authorized_keys inside the container, allowing SSH access for the user "chris":
COPY ./chrisops.pub  .ssh/authorized_keys

# The container is updated with necessary packages, including supervisor and openssh, without caching any files:
RUN apk update && apk add supervisor openssh --no-cache

# SSH keys are generated for the container:
RUN ssh-keygen -A

# The location of the sshd binary is moved:
RUN mv /usr/sbin/sshd /usr/bin/sshd

# SSH host keys are copied to the working directory:
RUN cp /etc/ssh/ssh_host* .

# The sshd_config file is modified to change the host key location:
RUN sed -i 's+#HostKey /etc/ssh/+HostKey /usr/local/apache2/+g' /etc/ssh/sshd_config

# The ownership of files and directories inside the container is changed to the user "chris":
RUN chown -R $USER. $HOME_DIR

# A supervisor.conf file is copied to the container:
COPY ./supervisor.conf .

# The container exposes ports 22 (SSH) and 80 (HTTP):
EXPOSE 22 80

# The user "chris" is set as the default user when the container starts:
USER $USER

# The entrypoint is set to run the supervisord command:
ENTRYPOINT ["/usr/bin/supervisord"]

# The supervisor.conf file is passed as an argument to supervisord:
CMD ["-c","supervisor.conf"]
```
## Final output

Once all prerequisites are read through, then you can test it directly by pasting the below snippet directly to the server. If you wish to change the username and private key files make sure you read the prerequisites
```sh
git clone https://github.com/Chris-luiz-16/ssh-a-docker-container-using-supervisord.git website
cd website
ssh-keygen -f chrisops -P ""
docker image build -t myimage:v1 .
docker container run --name myctr -d -p 80:80 myimage:v1
docker container ls -a
```
Once this is executed time to check whether we are able to ssh into the server. First, let's check the container's IP by inspecting the network bridge
```sh
docker network inspect bridge -f='{{range .Containers}}{{println .Name .IPv4Address}}{{end}}'
```
In my case, the output looks like
```
[ec2-user@ip-172-31-1-125 website]$ docker network inspect bridge -f='{{range .Containers}}{{println .Name .IPv4Address}}{{end}}'
myctr 172.17.0.2/16
```
Time to ssh into the server
```sh
ssh -i chrisops chris@172.17.0.2
```
The final output looks like
```sh
[ec2-user@ip-172-31-1-125 website]$ ssh -i chrisops chris@172.17.0.2
The authenticity of host '172.17.0.2 (172.17.0.2)' can't be established.
ED25519 key fingerprint is SHA256:KyLoXN6mfGfJVS0oWRvHiBJorgcqKqdYZpUm4Tujpe0.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '172.17.0.2' (ED25519) to the list of known hosts.
Welcome to Alpine!

The Alpine Wiki contains a large amount of how-to guides and general
information about administrating Alpine systems.
See <https://wiki.alpinelinux.org/>.

You can setup the system with the command: setup-alpine

You may change this message by editing /etc/motd.

4df0b881b304:/usr/local/apache2$
4df0b881b304:/usr/local/apache2$
```
