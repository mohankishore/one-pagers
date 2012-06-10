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

    private static class Controller {
        public String mode;
        public String filter;
        public String name;

        public Controller(HttpServletRequest request, HttpServletResponse response) {
            mode = nvl(request.getParameter("mode"), "queryNames");
            filter = nvl(request.getParameter("filter"));
            name = nvl(request.getParameter("name"));
        }
        
        public String execute() {
            if ("queryNames".equals(mode)) {
                return queryNames();
            } else if ("getAttributes".equals(mode)) {
                return getAttributes();
            }
            return "{ status: 'unexpected request mode' }";
        }
        
        public String queryNames() {
            MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
            // TODO: add filtering logic
            Set<ObjectName> names = mbs.queryNames(null, null);
            StringBuilder out = new StringBuilder();
            out.append("{ status: 'OK', ");
            out.append("total: " + ((names != null) ?names.size() :0) + ", ");
            out.append("data: [ ");
            if (names != null) for (ObjectName name : names) {
                String str = name.getDomain() + ":" + name.getKeyPropertyListString();
                out.append("{ name: '" + str + "' }, ");
            }
            out.append("] }");
            return out.toString();
        }
        
        public String getAttributes() {
            try {
                MBeanServer mbs = ManagementFactory.getPlatformMBeanServer();
                ObjectName objName = new ObjectName(name);
                MBeanInfo beanInfo = mbs.getMBeanInfo(objName);
                MBeanAttributeInfo[] attributeInfos = beanInfo.getAttributes();
                List<String> attributeNames = new ArrayList<String>(attributeInfos.length);
                for (int i=0; i < attributeInfos.length; i++) {
                    attributeNames.add(attributeInfos[i].getName());
                }
                Collections.sort(attributeNames);
                AttributeList attributeList = mbs.getAttributes(objName, attributeNames.toArray(new String[attributeInfos.length]));
                StringBuilder out = new StringBuilder();
                out.append("{ status: 'OK', data: [ ");
                for (Attribute a : attributeList.asList()) {
                    Object obj = a.getValue();
                    String value = "";
                    if (obj instanceof Object[]) {
                        for (Object o : (Object[]) obj) {
                            value += nvl(o) + "\n";
                        }
                    } else {
                        value = nvl(obj);
                    }
                    value = value.replaceAll("\n", "\\\\n");
                    out.append("{ name: '" + a.getName() + "', value: '" + value + "' }, ");
                }
                out.append("] }");
                return out.toString();
            } catch (Exception e) {
                return "{ status: 'ERROR: getting attributes for MBean named: " + name + " - " + e.getMessage() + "' }";
            }
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
<title>JMX Admin</title>
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
        "dijit/Tree", 
        "dijit/tree/TreeStoreModel", 
        "dojo/_base/xhr",
        "dojo/data/ObjectStore",
        "dojo/parser",
        "dojo/store/Memory",
        "dojox/grid/DataGrid",
    ]);
    
    var BASE_URL = '<%= request.getRequestURI() %>';

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

    function showTree(data) {
    	var rootNode = { label: "MBeans", children: [] };
    	for (var i in data) {
    		var nameNode = data[i];
    		var parentNode = findParentNode(rootNode, nameNode);
    		parentNode.children.push(nameNode);
    	}
        var treeStore = new dojo.data.ObjectStore({ objectStore: new dojo.store.Memory({
            data: [ rootNode ], 
        }) });
    
        var treeModel = new dijit.tree.TreeStoreModel({
            store: treeStore,
            labelAttr: 'label',
        });

        var tree = dijit.byId("tree");
        if (tree != null) {
        	tree.dndController = null;
            tree.destroyRecursive(true);
        }
        tree = new dijit.Tree({ 
        	id: 'tree',
        	model: treeModel,
        	showRoot: false,
        	onClick: function(item, node, evt) {
                if (item.name) selectMBean(item.name);
        	}
        }, document.createElement('div'));
        var node = dojo.byId("treePane");
        while (node.hasChildNodes()) node.removeChild(node.firstChild);
        node.appendChild(tree.domNode);
        tree.startup();
    }

    function findParentNode(rootNode, mbean) {
    	var arr = mbean.name.split(":");
    	var domain = arr[0], list = arr[1];
        //arr = list.split(",");
    	mbean.label = list;
    	for (var i in rootNode.children) {
    		var domainNode = rootNode.children[i]; 
    		if (domainNode.label == domain) {
    			return domainNode;
    		}
    	}
    	var domainNode = { label: domain, children: [] };
    	rootNode.children.push(domainNode);
    	return domainNode;
    }
    
    function selectMBean(name) {
        var xhrArgs = {
        	url: BASE_URL + "?mode=getAttributes&name=" + encodeURIComponent(name),
            handleAs: "json",
            load: function(response){
                if (response.status == "OK") {
                    var grid = dijit.byId("attributesGrid");
                    if (grid != null) {
                        grid.destroyRecursive(true);
                    }
                    grid = new dojox.grid.DataGrid(
                        {
                            id: 'attributesGrid',
                            store: new dojo.data.ObjectStore({ objectStore: new dojo.store.Memory({data: response.data}) }),
                            structure: [[
                                         { name: "Name", field: "name", width: "30%" },
                                         { name: "Value", field: "value", width: "70%", 
                                        	 formatter: function(val) { return val.replace(/\n/g, "<br>"); } 
                                         },
                            ]],
                            rowSelector: '20px',
                            selectable: true,
                        }, 
                        document.createElement('div')
                    );
                    var node = dojo.byId("attributesGrid");
                    while (node.hasChildNodes()) node.removeChild(node.firstChild);
                    node.appendChild(grid.domNode);
                    grid.startup();
                } else {
                    dojo.byId("status").innerHTML = response.status;
                    dojo.byId("attributesGrid").innerHTML = dojo.toJson(response);
                }
            },
            error: function(error){
              dojo.byId("status").innerHTML = error;
            }
        }
        dojo.byId("attributesGrid").innerHTML = "Form being sent...";
        dojo.xhrGet(xhrArgs);
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
</style>
</head>

<body class="claro">
<form id="AdminForm" method="GET" action="<%= request.getRequestURI() %>" data-dojo-type="dijit.form.Form">
<input type="hidden" name="mode" value="queryNames"/>

<div id="appContainer" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="">

<div id="toolbar" data-dojo-type="dijit.Toolbar" data-dojo-props="region: 'top'">
    <label>Filter:</label>
    <input name="filter" data-dojo-type="dijit.form.TextBox" value="<%= c.filter %>" style="width: 400px">
    
    <button data-dojo-type="dijit.form.Button" onClick="submitForm('AdminForm')" data-dojo-props="iconClass: 'dijitEditorIcon dijitEditorIconTabIndent'">Execute</button>
</div><!-- toolbar -->

<div id="mainPane" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="region: 'center'">

<div id="treePane" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'left', splitter: true" style="width: 300px"></div>

<div id="detailPane" data-dojo-type="dijit.layout.TabContainer" data-dojo-props="region: 'center'">
<div id="attributesPane" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="title: 'Attributes'">
<div id="attributesGrid" style="height: 100%"></div>
</div>
<div id="operationsPane" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="title: 'Operations'">To be done...</div>
</div>

</div><!-- main pane -->

<div id="status" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'bottom'">Status</div>

</div><!-- app container -->

</form>
</body>
</html>
