<%@page import="java.io.*,java.util.*,java.lang.management.*"%>
<%
    if ("PROD".equals(System.getProperty("my.env.property"))) {
        out.println("This page is not available in PROD");
        return;
    }
%>
<%!/**
     * @author Hariharan Vijayakumar
     * @author Mohan Kishore
     */

    private static String nvl(String s) {
        return nvl(s, "");
    }

    private static String nvl(String s, String def) {
        return (s != null) ? s : def;
    }

    private static class Controller {
        public int interval;
        public int depth;
        public int count;
        public String filter;

        public Controller(HttpServletRequest request, HttpServletResponse response) {
            interval = Integer.parseInt(nvl(request.getParameter("interval"), "500"));
            depth = Integer.parseInt(nvl(request.getParameter("depth"), "7"));
            count = Integer.parseInt(nvl(request.getParameter("count"), "25"));
            filter = nvl(request.getParameter("filter"));
        }

        public String getThreadHtmlData() {
            StringBuffer sb = new StringBuffer();
            sb.append("{");
            sb.append(getThreadSummary());
            sb.append(addThreadDataAsJSON());
            sb.append("status: 'OK', ");
            sb.append("}");
            return sb.toString();
        }

        private String getThreadSummary() {
            ThreadMXBean tBean = ManagementFactory.getThreadMXBean();

            StringBuffer sb = new StringBuffer();
            sb.append("active: ").append(tBean.getThreadCount()).append(", ");
            sb.append("total: ").append(tBean.getTotalStartedThreadCount()).append(", ");
            return sb.toString();
        }

        private List<ThreadData> getThreadData() {
            ThreadMXBean tBean = ManagementFactory.getThreadMXBean();

            long[] threadIdArray = tBean.getAllThreadIds();
            long[] initialCpuTime = new long[threadIdArray.length];
            for (int index = 0; index < threadIdArray.length; index++) {
                initialCpuTime[index] = tBean.getThreadCpuTime(threadIdArray[index]);
            }

            if (interval > 3000) {
                interval = 3000; // setting upper limit. waiting for than 3 seconds is not good
            }
            if (interval < 500) {
                interval = 500; //difficult to judge if interval is less than 500ms.
            }
            try {
                Thread.sleep(interval);
            } catch (InterruptedException e) {
                e.printStackTrace(); // discard exception as not critical
            }

            long finalCpuTime = -1;
            List<ThreadData> list = new ArrayList<ThreadData>();
            ThreadData data = null;
            for (int index = 0; index < threadIdArray.length; index++) {
                finalCpuTime = tBean.getThreadCpuTime(threadIdArray[index]);
                data = new ThreadData();
                data.threadId = threadIdArray[index];
                long diffTime = (finalCpuTime - initialCpuTime[index]) / 1000000;
                //System.out.println("Thread id = "+threadIdArray[index]+" initial="+initialCpuTime[index] +" final="+finalCpuTime+" diff="+diffTime);
                data.cpuTime = diffTime;
                data.totalCpuTime = (finalCpuTime / 1000000);
                list.add(data);
            }

            // sort by cpu time - descending
            Collections.sort(list, new Comparator<ThreadData>() {
               public int compare(ThreadData d1, ThreadData d2) {
                   return (int) (d2.cpuTime - d1.cpuTime);
               }
            });

            //sublist the thread list
            if (count > 0 && count < list.size()) {
                list = list.subList(0, count);
            }

            ThreadInfo info = null;
            //Looping seperately to avoid any delay in getting ThreadcPU time if 
            // getthreadinfo consumes considerable time.
            for (ThreadData dataTmp : list) {
                info = tBean.getThreadInfo(dataTmp.threadId, depth);
                dataTmp.threadName = info.getThreadName();
                dataTmp.threadStatus = info.getThreadState().name();
                dataTmp.stackTrace = getStackTraceString(info.getStackTrace());
            }

            //Filter if specified
            if (filter != null) {
                list = filterByString(list, filter);
            }

            return list;

        }

        private List<ThreadData> filterByString(List<ThreadData> dataList, String filter) {
            List<ThreadData> filteredList = new ArrayList<ThreadData>();
            for (ThreadData data : dataList) {
                if ((data.threadName != null && data.threadName.contains(filter))
                        || (data.threadStatus != null && data.threadStatus.contains(
                                filter))
                        || (data.stackTrace != null && data.stackTrace.contains(filter))) {
                    filteredList.add(data);
                }
            }
            return filteredList;

        }

        private String getStackTraceString(StackTraceElement[] stackTraceArray) {
            StringBuffer sb = new StringBuffer();
            if (stackTraceArray != null) {
                String newLine = System.getProperty("line.separator");
                for (int i = 0; i < stackTraceArray.length; i++) {
                    sb.append(stackTraceArray[i].toString());
                    sb.append(newLine);
                }
            }
            return sb.toString();
        }

        private String addThreadDataAsJSON() {
            List<ThreadData> list = getThreadData();
            
            StringBuilder sb = new StringBuilder();
            sb.append("data: [");
            for (ThreadData data : list) {
                sb.append("{");
                sb.append("id: ").append(data.threadId).append(", ");
                sb.append("name: '").append(data.threadName).append("', ");
                sb.append("status: '").append(data.threadStatus).append("', ");
                sb.append("cpuTime: ").append(data.cpuTime).append(", ");
                sb.append("cpuTotal: ").append(data.totalCpuTime).append(", ");
                sb.append("stackTrace: '").append(data.stackTrace.replaceAll("\n", "\\\\n")).append("', ");
                sb.append("}, ");
            }
            sb.append("], ");
            return sb.toString();
        }
    }

    private static class ThreadData {
        public long threadId = 0;
        public long cpuTime = 0;//total cpu time
        public long totalCpuTime = 0;
        public String threadStatus = null;
        public String threadName = null;
        public String stackTrace = null;
    }%>
<%
    Controller c = new Controller(request, response);
    if (request.getParameter("interval") != null) {
        out.println(c.getThreadHtmlData());
        return;
    }
%>
<html>
<head>
<title>Thread Admin</title>
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

    function submitForm(formName) {
        var xhrArgs = {
            form: formName,
            handleAs: "json",
            load: function(response){
                if (response.status == "OK") {
                    dojo.byId("status").innerHTML = "Active: " + response.active + ", Total: " + response.total;
                    var grid = dijit.byId("grid");
                    if (grid != null) {
                        grid.destroyRecursive(true);
                    }
                    grid = new dojox.grid.DataGrid(
                        {
                            id: 'grid',
                            store: new dojo.data.ObjectStore({ objectStore: new dojo.store.Memory({data: response.data}) }),
                            structure: [[
                                         { name: "ID", field: "id", width: "4%" },
                                         { name: "Name", field: "name", width: "15%" },
                                         { name: "Status", field: "status", width: "8%" },
                                         { name: "CPU", field: "cpuTime", width: "4%" },
                                         { name: "CPU(T)", field: "cpuTotal", width: "4%" },
                                         { name: "Stack Trace", field: "stackTrace", width: "65%" },
                            ]],
                            rowSelector: '20px',
                            selectable: true,
                        }, 
                        document.createElement('div')
                    );
                    var node = dojo.byId("results");
                    while (node.hasChildNodes()) node.removeChild(node.firstChild);
                    node.appendChild(grid.domNode);
                    grid.startup();
                } else {
                    dojo.byId("status").innerHTML = response.status;
                    dojo.byId("results").innerHTML = dojo.toJson(response);
                }
            },
            error: function(error){
              dojo.byId("results").innerHTML = error;
            }
        }
        dojo.byId("results").innerHTML = "Form being sent...";
        dojo.xhrPost(xhrArgs);
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

<div id="appContainer" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="">

<%--
<div id="topPanel" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="region: 'top', splitter: true" style="height: 200px">
--%>
<div id="toolbar" data-dojo-type="dijit.Toolbar" data-dojo-props="region: 'top'">
    <label>Interval (ms):</label>
    <input name="interval" data-dojo-type="dijit.form.NumberTextBox" value="<%= c.interval %>" style="width: 50px">
    <label>Stack Depth:</label>
    <input name="depth" data-dojo-type="dijit.form.NumberSpinner" value="<%= c.depth %>" style="width: 50px">
    <label>Max Count:</label>
    <input name="count" data-dojo-type="dijit.form.NumberSpinner" value="<%= c.count %>" style="width: 50px">
    <label>Filter:</label>
    <input name="filter" data-dojo-type="dijit.form.TextBox" value="<%= c.filter %>" style="width: 400px">
    
    <button data-dojo-type="dijit.form.Button" onClick="submitForm('AdminForm')" data-dojo-props="iconClass: 'dijitEditorIcon dijitEditorIconTabIndent'">Execute</button>
</div><!-- toolbar -->

<%--
<textarea name="query" class="monospace" data-dojo-type="dijit.form.SimpleTextarea" data-dojo-props="region: 'center'"><%=query%></textarea>
</div><!-- top panel -->
--%>

<div id="results" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'center'"></div>

<div id="status" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'bottom'">Status</div>

</div><!-- app container -->

</form>
</body>
</html>
