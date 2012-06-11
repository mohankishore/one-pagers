<%@page import="java.io.*,java.util.*"%>
<%
    if ("PROD".equals(System.getProperty("my.env.property"))) {
        out.println("This page is not available in PROD");
        return;
    }
%>
<%!/**
     * @author Mohan Kishore
     */

    private static String nvl(Object s) {
        return nvl(s, "");
    }
    
    private static String nvl(Object s, String def) {
        return (s != null) ? String.valueOf(s) : def;
    }
    
    private static class Controller {
        public ServletContext application;
        public String mode;
        public String pid;
        public String command;

        public Controller(HttpServletRequest request, HttpServletResponse response) {
            application = request.getServletContext();
            mode = nvl(request.getParameter("mode"));
            pid = nvl(request.getParameter("pid"));
            command = nvl(request.getParameter("command"));
        }

        public String execute() {
            try {
                if ("connect".equals(mode)) {
                    return connect();
                } else if ("execute".equals(mode)) {
                    return doExecute();
                } else {
                    return "{ status: 'unexpected request mode: " + mode + "' }";
                }
            } catch (Exception e) {
                e.printStackTrace();
                return "{ status: 'ERROR: " + e.getMessage() + "' }";
            }
        }
        
        public String connect() throws Exception {
            Process p = Runtime.getRuntime().exec("/bin/bash");
            long pid = new Random().nextLong(); // simulating a pid
            application.setAttribute("pid=" + pid, p);
            StringBuilder out = new StringBuilder();
            out.append("{ status: 'OK', ");
            out.append("pid: '" + pid + "', ");
            out.append("}");
            return out.toString();
        }

        public String doExecute() throws Exception {
            Process p = (Process) application.getAttribute("pid=" + pid);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            PrintStream p_out = new PrintStream(p.getOutputStream());
            Pipe p1 = new Pipe(p.getInputStream(), baos);
            Pipe p2 = new Pipe(p.getErrorStream(), baos);
            Thread t1 = new Thread(p1); t1.start();
            Thread t2 = new Thread(p2); t2.start();
            
            p_out.println(command);
            p_out.flush();
            
            System.out.println("Start polling");
            for (int i=0; i < 40 
                    && (System.currentTimeMillis() - p1.getLastModified() < 100 
                            || System.currentTimeMillis() - p1.getLastModified() < 100); 
                    i++) {
                Thread.sleep(25);
            }
            
            if ("exit".equals(command)) {
                p.getOutputStream().close();
                p.getInputStream().close();
                p.getErrorStream().close();
                p.destroy();
                application.removeAttribute("pid=" + pid);
            }

            p1.cancel();
            p2.cancel();
            
            String data = baos.toString();
            data = data.replaceAll("\\\\", "\\\\\\\\");
            data = data.replaceAll("\n", "\\\\n");
            data = data.replaceAll("'", "\\\\'");
            
            StringBuilder out = new StringBuilder();
            out.append("{ status: 'OK', ");
            out.append("out: '" + data + "', ");
            out.append("}");
            return out.toString();
        }

    }

    private static class Pipe implements Runnable {
        private InputStream in;
        private OutputStream out;
        private boolean cancelled;
        private long lastModified = Long.MAX_VALUE;
        
        public Pipe(InputStream in, OutputStream out) {
            this.in = in;
            this.out = out;
        }
        
        // allows us to check that output has started coming in
        public void init() {
            lastModified = Long.MAX_VALUE;
        }

        // keeps polling the input and pushing whatever it finds to the output
        // sleeps for 100ms if it doesn't find anything
        public void run() {
            byte[] buffer = new byte[1024];
            while (!cancelled) {
                int len = -1;
                try {
                    if (in.available() > 0 && (len = in.read(buffer)) != -1) {
                        System.out.write(buffer, 0, len);
                        synchronized (out) {
                            out.write(buffer, 0, len);
                            out.flush();
                        }
                        lastModified = System.currentTimeMillis();
                    } else {
                        Thread.sleep(100);
                    }
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            }
            in = null;
            out = null;
        }
        
        public void cancel() {
            this.cancelled = true;
        }
        
        public long getLastModified() {
            return lastModified;
        }
    }

%>
<%
    Controller c = new Controller(request, response);
    if (request.getParameter("mode") != null) {
        out.println(c.execute());
        return;
    }
%>
<html>
<head>
<title>Bash Admin</title>
<link rel="stylesheet" href="http://ajax.googleapis.com/ajax/libs/dojo/1.7.1/dojo/resources/dojo.css" media="screen"/>
<link rel="stylesheet" href="http://ajax.googleapis.com/ajax/libs/dojo/1.7.1/dijit/themes/claro/claro.css" media="screen"/>
<link rel="stylesheet" href="http://ajax.googleapis.com/ajax/libs/dojo/1.7.1/dojox/grid/resources/claroGrid.css" media="screen"/>
<script src="http://ajax.googleapis.com/ajax/libs/dojo/1.7.2/dojo/dojo.js" data-dojo-config="async: true, parseOnLoad: true"></script>
<script>
    require([
        "dijit/layout/BorderContainer", 
        "dijit/layout/TabContainer",
        "dijit/layout/ContentPane", 
        "dijit/Toolbar", 
        "dijit/form/Button", 
        "dijit/form/Form", 
        "dijit/form/TextBox", 
        "dijit/form/NumberTextBox", 
        "dijit/form/NumberSpinner", 
        "dojo/parser",
        "dojo/_base/xhr",
        "dojo/store/Memory",
        "dojo/data/ObjectStore",
        "dojox/grid/DataGrid",
    ]);

    var BASE_URL = '<%= request.getRequestURI() %>';

    function connect() {
        var xhrArgs = {
    	    url: BASE_URL,
    	    content: { mode: "connect" },
            handleAs: "json",
            load: function(response){
                if (response.status == "OK") {
                    dojo.byId("results").innerHTML = "Connected: " + response.pid + "<br><br>";
                    dojo.byId("AdminForm").pid.value = response.pid;
                    dojo.byId("command").focus();
                } else {
                    dojo.byId("results").innerHTML = response.status + "<br>" + dojo.toJson(response);
                }
            },
            error: function(error){
              dojo.byId("results").innerHTML = error;
            }
        }
        dojo.byId("results").innerHTML = "Form being sent...";
        dojo.xhrPost(xhrArgs);
    }    

    function clear() {
        dojo.byId("results").innerHTML = "";
        dojo.byId("command").focus();
    }

    function submitForm(formName) {
        dojo.byId("results").innerHTML += "<span class='command'>$ " + dojo.byId("command").value + "</span><br>";
        var xhrArgs = {
            form: formName,
            handleAs: "json",
            load: function(response){
            	var results = dojo.byId("results");
                if (response.status == "OK") {
                	var s = response.out;
                    s = s.replace(/</g, "&lt;");
                    s = s.replace(/>/g, "&gt;");
                	s = s.replace(/\n/g, "<br>");
                    results.innerHTML += s + "<br>";
                } else {
                    results.innerHTML += response.status + "<br>" + dojo.toJson(response) + "<br>";
                }
                results.lastChild.scrollIntoView(); 
            },
            error: function(error){
                var results = dojo.byId("results");
                results.innerHTML += error + "<br>";
                results.scrollTop = results.scrollHeight; 
            }
        }
        // dojo.byId("results").innerHTML = "Form being sent...";
        dojo.xhrPost(xhrArgs);
        dojo.byId("command").value = "";
        return false;
    }    
</script>
<style type="text/css">
    html, body {
      height: 100%;
      width: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden;
    }
    #appContainer {
      height: 100%;
      width: 100%;
    }
    #results {
      background: black;
      color: white;
      font-family: "Courier New", monospace !important;
      font-size: 110%;
      white-space: pre !important;
    }
    #command, #command .dijitInputInner {
      background: black !important;
      color: #ffff66;
      height: 30px;
      font-family: "Courier New", monospace !important;
      font-size: 120% !important;
      padding-left: 3px !important;
    }
    .command {
      color: #ffff66;
    }
</style>
</head>

<body class="claro">
<form id="AdminForm" method="GET" action="<%= request.getRequestURI() %>" data-dojo-type="dijit.form.Form" onSubmit="return submitForm('AdminForm')">
<input type="hidden" name="mode" value="execute"/>
<input type="hidden" name="pid" value=""/>

<div id="appContainer" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="">

<div id="toolbar" data-dojo-type="dijit.Toolbar" data-dojo-props="region: 'top'">
    <button id="connectButton" data-dojo-type="dijit.form.Button" onClick="connect()" 
        data-dojo-props="iconClass: 'dijitEditorIcon dijitEditorIconTabIndent'">Connect</button>
    <button id="clearButton" data-dojo-type="dijit.form.Button" onClick="clear()" 
        data-dojo-props="iconClass: 'dijitEditorIcon dijitEditorIconNewPage'">Clear</button>
</div><!-- toolbar -->

<div id="results" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'center'">
- Please click the "Connect" button to start a session. 
- Please use the "exit" command to shutdown your session gracefully. 
</div>

<input id="command" name="command" data-dojo-type="dijit.form.TextBox" 
    data-dojo-props="region: 'bottom', style: 'width: 100%', placeholder: 'type in your command'"></input>
 
</div><!-- app container -->

</form>
</body>
</html>
