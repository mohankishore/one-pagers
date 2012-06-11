<%@ page contentType="text/html;charset=windows-1252"%>
<%@ page import="java.io.*, java.util.*, java.sql.*, java.text.*, java.math.*, javax.sql.*, javax.naming.*" %>
<%@ page import="org.springframework.web.context.support.*, org.springframework.web.context.*"%>

<%
if ("PROD".equals(System.getProperty("my.env.property"))) {
    out.println("This page is not available in PROD");
    return;
}
%>
<%!
    private static String nvl(Object s) {
        return nvl(s, "");
    }
    
    private static String nvl(Object s, String def) {
        return (s != null) ? String.valueOf(s) : def;
    }
    
    private static final int MAX_CELL_LENGTH = 150;
    private static final String[] MAX_ROWS = {"10", "100", "1000", "10000" };

    private static Map<Integer,String> TYPES = new LinkedHashMap<Integer, String>();
    static {
        TYPES.put(-5, "BIGINT");
        TYPES.put(-2, "BINARY");
        TYPES.put(-7, "BIT");
        TYPES.put(16, "BOOLEAN");
        TYPES.put(1, "CHAR");
        TYPES.put(91, "DATE");
        TYPES.put(3, "DECIMAL");
        TYPES.put(8, "DOUBLE");
        TYPES.put(6, "FLOAT");
        TYPES.put(4, "INTEGER");
        TYPES.put(-4, "LONGVARBINARY");
        TYPES.put(-1, "LONGVARCHAR");
        TYPES.put(2, "NUMERIC");
        TYPES.put(7, "REAL");
        TYPES.put(5, "SMALLINT");
        TYPES.put(92, "TIME");
        TYPES.put(93, "TIMESTAMP");
        TYPES.put(-6, "TINYINT");
        TYPES.put(-3, "VARBINARY");
        TYPES.put(12, "VARCHAR");
        TYPES.put(-10, "CURSOR");
    }
    
    private String getTypeName(int type) throws SQLException {
        String str = TYPES.get(type);
        if (str != null) {
            str = str.substring(str.lastIndexOf('.')+1);
        }
        return str;
    }

    private Connection getConnection(ServletContext servletContext, String dataSourceName) throws Exception {
        WebApplicationContext ctx = WebApplicationContextUtils.getWebApplicationContext(servletContext);
        DataSource dataSource = (DataSource) ctx.getBean(dataSourceName);
        return dataSource.getConnection();
    }

    private String[] findPoolNames(ServletContext servletContext) {
        WebApplicationContext ctx = WebApplicationContextUtils.getWebApplicationContext(servletContext);
        return ctx.getBeanNamesForType(DataSource.class);
    }

    /*
    private void setParams(PreparedStatement stmt, Map<Integer,Properties> params) throws SQLException {
        CallableStatement cstmt = null;
        if (stmt instanceof CallableStatement) cstmt = (CallableStatement) stmt;
        for (Map.Entry<Integer,Properties> entry : params.entrySet()) {
            int ndx = entry.getKey();
            Properties param = entry.getValue();
            int type = Integer.parseInt(param.getProperty("type"));
            String mode = param.getProperty("mode");
            if (mode.startsWith("IN")) {
                Object value = getParamObject(type, param.getProperty("value"));
                stmt.setObject(ndx, value);
            }
            if (mode.endsWith("OUT") && cstmt != null) {
                cstmt.registerOutParameter(ndx, type);
            }
        }
    }
    private Object getParamObject(int type, String s) throws SQLException {
        if ("".equals(s)) {
            return null;
        } else if (type == Types.BIGINT) {
            return new BigInteger(s);
        } else if (type == Types.BIT) {
            return s.getBytes()[0];
        } else if (type == Types.BOOLEAN || type == Types.BINARY) {
            return Boolean.valueOf(s);
        } else if (type == Types.CHAR) {
            return s.charAt(0);
        } else if (type == Types.DATE) {
            try {
                return new java.sql.Date(new SimpleDateFormat("yyyy-mm-dd hh:MM:ss").parse(s).getTime());
            } catch (ParseException e) {
                throw new SQLException("Error parsing the date (yyyy-mm-dd hh:MM:ss): " + s);
            }
        } else if (type == Types.DECIMAL || type == Types.NUMERIC) {
            return new BigDecimal(s);
        } else if (type == Types.DOUBLE) {
            return Double.parseDouble(s);
        } else if (type == Types.FLOAT || type == Types.REAL) {
            return Float.parseFloat(s);
        } else if (type == Types.INTEGER) {
            return Integer.parseInt(s);
        } else if (type == Types.LONGVARBINARY || type == Types.VARBINARY) {
            return s.getBytes();
        } else if (type == Types.LONGVARCHAR || type == Types.VARCHAR) {
            return s;
        } else if (type == Types.SMALLINT) {
            return Short.parseShort(s);
        } else if (type == Types.TIME) {
            try {
                return new Time(new SimpleDateFormat("yyyy-mm-dd hh:MM:ss").parse(s).getTime());
            } catch (ParseException e) {
                throw new SQLException("Error parsing the date (yyyy-mm-dd hh:MM:ss): " + s);
            }
        } else if (type == Types.TIMESTAMP) {
            try {
                return new Timestamp(new SimpleDateFormat("yyyy-mm-dd hh:MM:ss").parse(s).getTime());
            } catch (ParseException e) {
                throw new SQLException("Error parsing the date (yyyy-mm-dd hh:MM:ss): " + s);
            }
        } else if (type == Types.TINYINT) {
            return Byte.parseByte(s);
        } else {
            return null;
        }
    }
    */

    private void displayResults(PrintWriter pw, Statement stmt, boolean isRS, Map<Integer,Properties> params)
            throws SQLException {
        do {
            if (isRS) {
                ResultSet rs = stmt.getResultSet();
                displayResultSet(pw, rs, stmt.getMaxRows());
            } else {
                int uc = stmt.getUpdateCount();
                if (uc == -1) {
                    break;
                } else {
                    displayUpdateCount(pw, uc);
                }
            }
            isRS = stmt.getMoreResults();
        } while (isRS || stmt.getUpdateCount() != -1);
        /*
        // process output parameters
        if (stmt instanceof CallableStatement) {
            CallableStatement cstmt = (CallableStatement) stmt;
            for (Map.Entry<Integer,Properties> entry : params.entrySet()) {
                int ndx = entry.getKey();
                Properties param = entry.getValue();
                String mode = param.getProperty("mode");
                if (mode.endsWith("OUT")) {
                    int type = Integer.parseInt(param.getProperty("type"));
                    String typeName = getTypeName(type);
                    Object value = cstmt.getObject(ndx);
                    pw.println("<br/>");
                    pw.println("OUT parameter["+ndx+"]: Type="+typeName);
                    if (type == -10) { // ORACLE_CURSOR
                        displayResultSet(pw, (ResultSet) value, stmt.getMaxRows());
                    } else {
                        pw.println(" Value="+value+"<br/>");
                    }
                }
            }
        }
        */
    }

    private void displayResultSet(PrintWriter pw, ResultSet rs, int maxRows)
            throws SQLException {
        ResultSetMetaData rsmd = rs.getMetaData();
        int colCount = rsmd.getColumnCount();
        pw.println("{");
        pw.println("layout: [[");
        for (int i=1; i <= colCount; i++) {
            pw.println("{ name: '"+rsmd.getColumnLabel(i)+"', field: 'c" + i +"', width: '" + (100/colCount) + "%' }, ");
        }
        pw.println("]], "); // end layout
        pw.println("data: [");
        for (int j=0; j < maxRows && rs.next(); j++) {
            pw.println("{");
            for (int i=1; i <= colCount; i++) {
                Object obj = rs.getObject(i);
                if (obj == null || obj.toString().trim().equals("")) {
                  obj = "";
                } else {
                    String str = obj.toString();
                    if (str.length() > MAX_CELL_LENGTH) {
                        str = str.substring(0, MAX_CELL_LENGTH) + "...";
                    }
                    obj = str;
                }
                pw.println("c" + i + ": '"+obj+"', ");
            }
            pw.println("}, "); // end row
        }
        pw.println("]"); // end data
        pw.println("}");
        rs.close();
    }

    private void displayUpdateCount(PrintWriter pw, int uc)
            throws SQLException {
        pw.println("{ layout: [[ { name: 'Update Count', field: 'c1', width: '100%' } ]], data: [ { c1: '"+uc+"' } ] }");
    }

    // END CLASS CODE
%>
<%
    // BEGIN REQUEST CODE
    String poolName = nvl(request.getParameter("poolName"));
    String maxRows = nvl(request.getParameter("maxRows"), "100");
    String query = nvl(request.getParameter("query")).trim();
    Map<Integer,Properties> params = new TreeMap<Integer,Properties>();
    if (!query.equals("")) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        /*
        for (int i=1; true; i++) {
            String pref = "param" + i;
            if ("".equals(nvl(request.getParameter(pref+".mode")))) break;
            Properties param = new Properties();
            param.setProperty("mode", nvl(request.getParameter(pref+".mode")));
            param.setProperty("type", nvl(request.getParameter(pref+".type")));
            param.setProperty("value", nvl(request.getParameter(pref+".value")));
            params.put(i, param);
        }
        */
        Connection con = null;
        PreparedStatement stmt = null;
        long start = System.currentTimeMillis();
        long timing = 0;
        String status = "OK";
        try {
            con = getConnection(application, poolName);
            /*
            // hack for the XSS filter
            if (query.toLowerCase().startsWith("call ")) {
                query = "{ " + query + " }";
            }
            query = query.replaceAll("&gt;", ">");
            query = query.replaceAll("&lt;", "<");
            */
            if (query.startsWith("{")) {
                stmt = con.prepareCall(query);
            } else {
                stmt = con.prepareStatement(query);
            }
            stmt.setMaxRows(Integer.parseInt(maxRows));
            //setParams(stmt, params);
            boolean isRS = stmt.execute();
            displayResults(pw, stmt, isRS, params);
        } catch (Exception e) {
            e.printStackTrace();
            status = "ERROR: " + e.getMessage();
            sw = new StringWriter();
            sw.write("{}");
        } finally {
            timing = (System.currentTimeMillis() - start);
            try { stmt.close(); } catch (Exception e) {}
            try { con.close(); } catch (Exception e) {}
        }
        out.println("{ timing: " + timing);
        out.println(", status: '" + status.trim() + "'");
        out.println(", response: " + sw.toString());
        out.println("}");
        return;
    }
    String[] poolNames = findPoolNames(application);
%>
<html>
<head>
<title>DB Admin</title>
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
        "dijit/form/FilteringSelect", 
        "dijit/form/SimpleTextarea", 
        "dojo/parser",
        "dojo/_base/xhr",
        "dojo/store/Memory",
        "dojo/data/ObjectStore",
        "dojox/grid/DataGrid",
    ]);
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
<script type="text/javascript" language="JavaScript">
    <%--
    function addParam(mode, type, value) {
        var i = eval(document.forms['DBForm'].paramCount.value) + 1;
        document.forms['DBForm'].paramCount.value = i;
        var str = "<div id='param"+i+"' class='paramRow'>";
        str += "<input type='text' name='param"+i+"' value='"+i+"' size='2' disabled/> ";
        str += "<select name='param"+i+".mode'>"+getModeOptions(mode)+"</select> ";
        str += "<select name='param"+i+".type'>"+getTypeOptions(type)+"</select> ";
        str += "<input type='text' name='param"+i+".value' size='50' value='"+value+"'/> ";
        str += "<a href='javascript: removeParam("+i+")'>Remove</a>";
        str += "</div>";
        document.getElementById('paramArea').innerHTML += str;
    }

    var MODES = ['IN', 'INOUT', 'OUT'];
    function getModeOptions(id) {
        var str = "";
        for (var i=0; i < MODES.length; i++) {
            str += "<option";
            if (id == MODES[i]) str += " selected";
            str += ">" + MODES[i] + "</option>";
        }
        return str;
    }
    var TYPES = {};
    <% for (int i : TYPES.keySet()) { %>
    TYPES[<%=i%>] = "<%= TYPES.get(i) %>";
    <% } %>

    function getTypeOptions(id) {
        var str = "";
        for (var key in TYPES) {
            str += "<option value='"+key+"'";
            if (id == key) str += " selected";
            str += ">" + TYPES[key] + "</option>";
        }
        return str;
    }

    function removeParams() {
        document.forms['DBForm'].paramCount.value = 0;
        document.getElementById('paramArea').innerHTML = '';
    }

    function removeParam(id) {
        var i = eval(document.forms['DBForm'].paramCount.value) - 1;
        document.forms['DBForm'].paramCount.value = i;
        var el = document.getElementById('param'+id);
        el.parentNode.removeChild(el);
    }
    --%>
    function submitForm(formName) {
        var xhrArgs = {
            form: formName,
            handleAs: "json",
            load: function(response){
                dojo.byId("status").innerHTML = "Timing: " + response.timing + " ms";
                if (response.status == "OK") {
                    var grid = dijit.byId("grid");
                    if (grid != null) {
                        grid.destroyRecursive(true);
                    }
                    grid = new dojox.grid.DataGrid(
                        {
                            id: 'grid',
                            store: new dojo.data.ObjectStore({ objectStore: new dojo.store.Memory({data: response.response.data}) }),
                            structure: response.response.layout,
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
                    dojo.byId("results").innerHTML = response.status;
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
</head>

<body class="claro">
<form id="DBForm" method="post" action="<%= request.getRequestURI() %>" data-dojo-type="dijit.form.Form">
<input type="hidden" name="paramCount" value="0"/>

<div id="appContainer" data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="">

<div data-dojo-type="dijit.layout.BorderContainer" data-dojo-props="region: 'top', splitter: true" style="height: 200px">
<div data-dojo-type="dijit.Toolbar" data-dojo-props="region: 'top'">
    <label for="poolName">PoolName:</label>
    <select name="poolName" data-dojo-type="dijit.form.FilteringSelect">
    <%
    for (String pName : poolNames) {
        String selected = poolName.equals(pName) ?"selected" :"";
        %>
        <option <%=selected%>><%=pName%></option>
        <%
    }
    %>
    </select>
    <label for="maxRows">Max Rows:</label>
    <select name="maxRows" data-dojo-type="dijit.form.FilteringSelect">
    <%
    for (String mRows : MAX_ROWS) {
        String selected = maxRows.equals(mRows) ?"selected" :"";
        %>
        <option <%=selected%>><%=mRows%></option>
        <%
    }
    %>
    </select>
    <%--
    <button data-dojo-type="dijit.form.Button" onClick="addParam('IN', 4, '')">Add Parameter</button>
    <button data-dojo-type="dijit.form.Button" onClick="removeParams()">Remove Parameters</button>
    --%>
    <button data-dojo-type="dijit.form.Button" onClick="submitForm('DBForm')" data-dojo-props="iconClass: 'dijitEditorIcon dijitEditorIconTabIndent'">Execute</button>
</div><!-- toolbar -->

<textarea name="query" class="monospace" data-dojo-type="dijit.form.SimpleTextarea" data-dojo-props="region: 'center'"><%=query%></textarea>

<%--
<div id="paramArea"data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'bottom'"></div>
<script type="text/javascript">
  <%
  for (Map.Entry<Integer,Properties> entry : params.entrySet()) {
      Properties param = entry.getValue();
      String mode = param.getProperty("mode");
      int type = Integer.parseInt(param.getProperty("type"));
      String value = nvl(param.getProperty("value"));
      %>
      addParam('<%=mode%>', <%=type%>, '<%=value%>');
  <% } %>  
</script>
</div>
--%>
</div><!-- top panel -->

<div id="results" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'center'"></div>

<div id="status" data-dojo-type="dijit.layout.ContentPane" data-dojo-props="region: 'bottom'">Status</div>

</div><!-- app container -->

</form>
</body>
</html>
