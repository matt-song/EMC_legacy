```c

### apache setting ###

Alias /lab /opt/web/lab/htdoc 

<Directory /opt/web/lab/htdoc> 
  Order allow,deny
  Allow from all
  Require all granted
</Directory>

```
