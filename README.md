one-pagers
==========

This project is a loose collection of single-page self-contained JSP files that make your life easier when troubleshooting issues. 

These files will obviously get no love from your info-sec team! In most cases, it should be fine if you put them all under some 
protected URI (e.g. /admin/\*) - but please exercise your judgement in how you plan on using/deploying them.

The project currently comprises of the following page(s):

db_admin.jsp
------------

The JSP assumes that you are working in a "Spring" environment - if that is not the case, please tweak the logic to lookup the 
data-sources. The page allows you to select the data-source you wish to run your queries against and set the maximum rows you 
want fetched for any query. 

The sample web-app uses an embedded HSQLDB to demo the functionality. Please create a test table on the first run:

    create table test (id integer not null, name varchar(100) not null, description varchar(200), primary key (id))

Followed by:

    insert into test values(1, 'hello', 'world')


To be done:
-----------

* Log admin
* JMX admin
* Thread admin - will show top threads

Please drop me a line if you have more ideas on things that you would like to see here!