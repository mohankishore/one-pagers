one-pagers
==========

This project is a loose collection of single-page self-contained JSP files that make your life easier when troubleshooting issues.
Each JSP is completely self-contained - no dependency on other java classes or JSP pages. Just pick the JSP you need from
https://github.com/mohankishore/one-pagers/tree/master/src/main/webapp/admin and copy it over to one of your java web-applications! 

These files will obviously get no love from your info-sec team! In most cases, it should be fine if you put them all under some 
protected URI (e.g. /admin/\*) - but please exercise your judgement in how you plan on using/deploying them.

The project currently comprises of the following page(s):


db_admin.jsp
------------

This JSP assumes that you are working in a "Spring" environment - if that is not the case, please tweak the logic to lookup the 
data-sources. The page allows you to select the data-source you wish to run your queries against and set the maximum rows you 
want fetched for any query. 

The sample web-app uses an embedded HSQLDB to demo the functionality. Please create a test table on the first run.

    -- Sample SQLs: please execute one at a time
    create table test (id integer not null, name varchar(100) not null, description varchar(200), primary key (id))
    insert into test values(1, 'hello', 'world')
    insert into test values(2, 'foo', 'bar')
    select * from test where id <> 1 

<b>Screenshot</b>
![DB Admin](https://github.com/mohankishore/one-pagers/raw/master/img/db_admin.png)


thread_admin.jsp
----------------

This JSP uses the Thread MX Bean to lookup the thread information. It essentially takes two thread dumps a configurable interval
apart (500 ms by default) and shows you the top threads executing during this interval. The page accepts a search pattern to 
filter the threads as well as options to limit the number of threads and/or the depth of the stack trace that is returned.
 
<b>Screenshot</b>
![Thread Admin](https://github.com/mohankishore/one-pagers/raw/master/img/thread_admin.png)
 

jmx_admin.jsp
-------------

This JSP tries to replicate some/most of the functionality provided by the MBean tab within JConsole. The current implementation
offers read-only support for viewing the MBeans and their attributes. The JSP handles "array" values fairly gracefully and just
uses the default "toString" conversion in most other cases.

<b>Screenshot</b>
![JMX Admin](https://github.com/mohankishore/one-pagers/raw/master/img/jmx_admin.png)


bash_admin.jsp
--------------

This JSP provides a limited shell emulation support. It spawns a child process using the java Runtime.exec() call - which will
execute as the user that launched the servlet container process. It reads the user-input one line at a time - NOT character by
character i.e. cannot use "vi" etc. But it does allows you to browse around the filesystem, look at files, add/remove/copy/move
them, start/shutdown processes etc.

<b>Screenshot</b>
![Bash Admin](https://github.com/mohankishore/one-pagers/raw/master/img/bash_admin.png)


visualvm.jsp
--------------

This JSP tries to replicate some of the functionality provided by the Visual VM tool. The current implementation shows you the 
JVM startup arguments and system properties. Working on adding the charts to show the current CPU/Memory/Classes/Threads info.

<b>Screenshot</b>
![Visual VM](https://github.com/mohankishore/one-pagers/raw/master/img/visualvm.png)


To be done:
-----------

* Log admin
* File Explorer

Please drop me a line if you have more ideas on things that you would like to see here!