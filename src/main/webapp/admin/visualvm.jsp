<%@page import="java.io.*, java.util.*, java.lang.management.*, javax.management.*"%>
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

    private static String toJSON(String data) {
        // '\' with '\\'
        data = data.replaceAll("\\\\", "\\\\\\\\");
        // new-line with '\n'
        data = data.replaceAll("\n", "\\\\n");
        // escape the single quotes
        data = data.replaceAll("'", "\\\\'");
        return data;        
    }
    
    private static class Controller {
        public String mode;
        public String name;

        public Controller(HttpServletRequest request, HttpServletResponse response) {
            mode = nvl(request.getParameter("mode"), "queryNames");
            name = nvl(request.getParameter("name"));
        }
        
        public String execute() {
            if ("getRuntimeInfo".equals(mode)) {
                return getRuntimeInfo();
            } else if ("getAttributes".equals(mode)) {
                //return getAttributes();
            }
            return "{ status: 'unexpected request mode' }";
        }
        
        public String getRuntimeInfo() {
            RuntimeMXBean r = ManagementFactory.getRuntimeMXBean();
            Map<String,String> sp = r.getSystemProperties();
            StringBuilder out = new StringBuilder();
            out.append("{ status: 'OK', ");
            // raw data as exposed by MBean            /*
            out.append("bootClassPath: '" + toJSON(r.getBootClassPath()) + "', ");
            out.append("classPath: '" + toJSON(r.getClassPath()) + "', ");
            out.append("libraryPath: '" + toJSON(r.getLibraryPath()) + "', ");
            out.append("managementSpecVersion: '" + toJSON(r.getManagementSpecVersion()) + "', ");
            out.append("name: '" + toJSON(r.getName()) + "', ");
            out.append("specName: '" + toJSON(r.getSpecName()) + "', ");
            out.append("specVendor: '" + toJSON(r.getSpecVendor()) + "', ");
            out.append("specVersion: '" + toJSON(r.getSpecVersion()) + "', ");
            out.append("startTime: " + r.getStartTime() + ", ");
            out.append("uptime: " + r.getUptime() + ", ");
            out.append("vmName: '" + toJSON(r.getVmName()) + "', ");
            out.append("vmVendor: '" + toJSON(r.getVmVendor()) + "', ");
            out.append("vmVersion: '" + toJSON(r.getVmVersion()) + "', ");
            // formatted data as expected by visualvm
            out.append("overview: {");
            String name = r.getName();
            out.append("pid: '" + name.substring(0, name.indexOf('@')) + "', ");
            out.append("host: '" + name.substring(name.indexOf('@') + 1) + "', ");
            String command = sp.get("sun.java.command");
            out.append("mainClass: '" + command.substring(0, command.indexOf(' ')) + "', ");
            out.append("arguments: '" + toJSON(command.substring(command.indexOf(' ') + 1)) + "', ");
            out.append("jvm: '" + sp.get("java.vm.name") + " (" + sp.get("java.vm.version") + ", " + sp.get("java.vm.info") + ")', ");
            out.append("java: 'version " + sp.get("java.version") + ", vendor " + sp.get("java.vendor") + "', ");
            out.append("javaHome: '" + toJSON(sp.get("java.home")) + "', ");
            out.append("jvmFlags: '<none>', ");
            out.append("heapDumpOnOOME: 'disabled', ");
            out.append("}, ");
            // command line arguments
            out.append("inputArguments: [ ");
            TreeSet<String> sortedSet = new TreeSet<String>(r.getInputArguments());
            for (String arg : sortedSet) {
                out.append("'" + toJSON(arg) + "', ");
            }
            out.append("], ");
            // system properties
            out.append("systemProperties: [ ");
            TreeMap<String,String> sortedMap = new TreeMap<String,String>(sp);
            for (Map.Entry<String,String> prop : sortedMap.entrySet()) {
                out.append("{ name: '" + toJSON(prop.getKey()) + "', value: '" + toJSON(prop.getValue()) + "' }, ");
            }
            out.append("], ");
            out.append("}");
            return out.toString();
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
<title>Visual VM</title>
<link rel="stylesheet" href="http://ajax.googleapis.com/ajax/libs/dojo/1.7.1/dojo/resources/dojo.css" media="screen"/>
<link rel="stylesheet" href="http://ajax.googleapis.com/ajax/libs/dojo/1.7.1/dijit/themes/claro/claro.css" media="screen"/>
<link rel="stylesheet" href="http://ajax.googleapis.com/ajax/libs/dojo/1.7.1/dojox/grid/resources/claroGrid.css" media="screen"/>
<script src="http://ajax.googleapis.com/ajax/libs/dojo/1.7.2/dojo/dojo.js" data-dojo-config="async: true, parseOnLoad: true"></script>
<script>
    require([
        "dijit/form/Button", 
        "dijit/form/Form", 
        "dijit/form/TextBox", 
        "dijit/form/NumberTextBox", 
        "dijit/form/NumberSpinner", 
        "dijit/layout/BorderContainer", 
        "dijit/layout/TabContainer",
        "dijit/layout/ContentPane", 
        "dijit/Toolbar", 
        "dojo/_base/xhr",
        "dojo/data/ObjectStore",
        "dojo/parser",
        "dojo/store/Memory",
        "dojox/dtl",
        "dojox/dtl/Context",
        "dojox/grid/DataGrid",
    ], onLoad);
    
    var BASE_URL = '<%= request.getRequestURI() %>';
    
    function toHTML(s) {
        s = s.replace(/</g, "&lt;");
        s = s.replace(/>/g, "&gt;");
        s = s.replace(/\n/g, "<br>");
        return s;
    }

    function submitForm(formName) {
        var xhrArgs = {
            form: formName,
            handleAs: "json",
            load: function(response){
                if (response.status == "OK") {
                    dojo.byId("status").innerHTML = "Total: " + response.total;
                    showTree(response.data);
                } else {
                    dojo.byId("status").innerHTML = response.status;
                    dojo.byId("treePane").innerHTML = dojo.toJson(response);
                }
            },
            error: function(error){
              dojo.byId("status").innerHTML = error;
            }
        }
        dojo.byId("treePane").innerHTML = "Form being sent...";
        dojo.xhrPost(xhrArgs);
    }    

    function getRuntimeInfo() {
        var xhrArgs = {
            url: BASE_URL + "?mode=getRuntimeInfo",
            handleAs: "json",
            load: function(response){
                if (response.status == "OK") {
                    var template = new dojox.dtl.Template(dojo.byId('overviewContentsTemplate').innerHTML);
                    var context = new dojox.dtl.Context(response.overview);
                    dojo.byId('overviewContents').innerHTML = template.render(context);

                    template = new dojox.dtl.Template(dojo.byId('jvmArgumentsTemplate').innerHTML);
                    context = new dojox.dtl.Context(response);
                    dojo.byId('jvmArgumentsPane').innerHTML = template.render(context);

                    var grid = dijit.byId("sysPropsGrid");
                    if (grid != null) {
                        grid.destroyRecursive(true);
                    }
                    grid = new dojox.grid.DataGrid(
                        {
                            id: 'sysPropsGrid',
                            store: new dojo.data.ObjectStore({ objectStore: new dojo.store.Memory({data: response.systemProperties}) }),
                            structure: [[
                                         { name: "Name", field: "name", width: "30%" },
                                         { name: "Value", field: "value", width: "70%", 
                                             formatter: function(val) { return toHTML(val); } 
                                         },
                            ]],
                            rowSelector: '20px',
                            selectable: true,
                        }, 
                        document.createElement('div')
                    );
                    var node = dojo.byId("systemPropertiesPane");
                    while (node.hasChildNodes()) node.removeChild(node.firstChild);
                    node.appendChild(grid.domNode);
                    grid.startup();
                } else {
                    alert( dojo.fromJson(response) );
                }
            },
            error: function(error){
              alert( error );
            }
        }
        dojo.xhrGet(xhrArgs);
    }
    
    function onLoad() {
    	getRuntimeInfo();
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
    .monospace {
      font-family: "Courier New" monospace;
      font-size: 110%;
    }
    .title {
      padding: 5px;
      margin: 0px;
      background: #f0f5ff;
      border: 1px solid #ccc;
    }
</style>
</head>

<body class="claro">
<form id="AdminForm" method="GET" action="<%= request.getRequestURI() %>" data-dojo-type="dijit.form.Form">
<input type="hidden" name="mode" value="queryNames"/>

<div id="appContainer" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="">

<div id="mainTabContainer" data-dojo-type="dijit.layout.TabContainer" data-dojo-props="region: 'center'">

<div id="overviewContainer" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="title: 'Overview'">
    <div id="overviewPane" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'top', splitter: true" 
        style="height: 250; border: 0; padding: 0">
        <div class="title">Overview</div>
        <div id="overviewContents" style="padding: 20; line-height: 150%"></div>
    </div>
    <div id="detailsTabContainer" data-dojo-type="dijit.layout.TabContainer" data-dojo-props="region: 'center'">
        <div id="jvmArgumentsPane" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="title: 'JVM Arguments'" 
            style="padding: 20; line-height: 150% !important"></div>
        <div id="systemPropertiesPane" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="title: 'System Properties'"></div>
    </div>
</div>

<div id="monitorContainer" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="title: 'Monitor'">
</div>

</div><!-- main tab container -->

</div><!-- app container -->

</form>

<!-- hide all the templates -->
<div style="display: none">

<div id="overviewContentsTemplate">
    <b>PID:</b> {{pid}}<br>
    <b>Host:</b> {{host}}<br>
    <b>Main class:</b> {{mainClass}}<br>
    <b>Arguments:</b> {{arguments}}<br>
    <br>
    <b>JVM:</b> {{jvm}}<br>
    <b>Java:</b> {{java}}<br>
    <b>Java Home:</b> {{javaHome}}<br>
    <b>JVM Flags:</b> {{jvmFlags}}<br>
    <br>
    <b>Heap dump on OOME:</b> {{heapDumpOnOOME}}<br>
</div>

<div id="jvmArgumentsTemplate">
{% for arg in inputArguments %}
    {{ arg }}<br>
{% endfor %}
</div>

</div>

</body>
</html>
