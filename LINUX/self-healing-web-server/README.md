# CloudPros Infrastructure Setup

## HOW I SET UP THE PROJECT. 

The project is secure, self healing linux web server deployed on Ubuntu. I used **UFW** as firewall to manage incoming traffic, **NGINX** as reverse proxy to manage web traffic. I also use **systemd** to manage the application lifecycle and **logs** monitor the application activity.

## HOW DOES CLOUDPROS-APP WORK WITH NGINX

NGINX acts a proxy listening to request on port 80(HTTP) and when such request come in it redirects it to port 8000 which the application listens on internally.

## HOW DOES SYSTEMD HANDLE APPLICATION RECOVERY

Systemd has attributes such as Restart=failure,RestartSec. which allows systemd to restart the service when it fails. And the service it self was enable to auto start on system power and boot.

## HEALTH MONITORING WORKS 

Systemd regularly tests for HTTP connection and failsafe was put in place so incase of a disconnection or failed request a restart to performed. Every activity is being logged.

## BACKUPS AND LOGS ROTATION CONFIGURED

The logs are configured to recieve new entry per minute and older logs are deleted afer 7 days and backup is configured to be made daily and after seven days older backups are deleted.

- Challenges and Solutions encountered.
- readonly service file.
 - Solution: begin with a sudo command to elevate user permission.
- Service fails to start after modification.
 - Solution: Restart systemd daemon and the service it self
- Socat not connecting:

* cloud-pros.service 
    Process: 13290 ExecStart=/usr/bin/socat TCP-LISTEN:8000,fork,reuseaddr,bind=127.0.0.1 Exec:/opt/cloudpros/cl>
   Main PID: 13290 (code=exited, status=203/EXEC)

 - Checked the logs: found out that the directory for socat I was using doesn’t exist

  


 

