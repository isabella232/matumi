module namespace templates="http://exist-db.org/xquery/templates";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace theme="http:/exist-db.org/xquery/matumi/theme" at "theme.xqm";

declare function templates:apply($content as node()+, $modules as element(modules), $model as item()*) {
    let $imports := templates:import-modules($modules)
    let $prefixes := (templates:extract-prefixes($modules), "templates:")
    let $null := request:set-attribute("$templates:prefixes", $prefixes)
    for $root in $content
    return
        templates:process($root, $prefixes, $model)
};

declare function templates:process($node as node(), $prefixes as xs:string*, $model as item()*) {
    typeswitch ($node)
        case document-node() return
            for $child in $node/node() return templates:process($child, $prefixes, $model)
        case element() return
            let $class := $node/@class
            return
                if ($class and templates:matches-prefix($class, $prefixes)) then
                    templates:call($class, $node, $model)
                else
                    element { node-name($node) } {
                        $node/@*, for $child in $node/node() return templates:process($child, $prefixes, $model)
                    }
        default return
            $node
};

declare function templates:call($class as xs:string, $node as node(), $model as item()*) {
    let $paramStr := substring-after($class, "?")
    let $parameters := templates:parse-parameters($paramStr)
    let $log := util:log("DEBUG", ("params: ", $parameters))
    let $func := if ($paramStr) then substring-before($class, "?") else $class
    let $call := concat($func, "($node, $parameters, $model)")
    return
        util:eval($call)
};

declare function templates:parse-parameters($paramStr as xs:string?) {
    <parameters>
    {
        for $param in tokenize($paramStr, "&amp;")
        let $key := substring-before($param, "=")
        let $value := substring-after($param, "=")
        where $key
        return
            <param name="{$key}" value="{$value}"/>
    }
    </parameters>
};

declare function templates:import-modules($modules as element(modules)?) {
    for $module in $modules/module
    return
        util:import-module($module/@uri, $module/@prefix, $module/@at)
};

declare function templates:matches-prefix($class as xs:string, $prefixes as xs:string*) {
    for $prefix in $prefixes
    return
        if (starts-with($class, $prefix)) then true()
        else ()
};

declare function templates:extract-prefixes($modules as element(modules)) as xs:string* {
    for $module in $modules/module
    return
        concat($module/@prefix/string(), ":")
};

declare function templates:include($node as node(), $params as element(parameters)?, $model as item()*) {
    let $relPath := $params/param[@name = "path"]/@value
    let $path := concat($config:app-root, "/", $relPath)
    let $prefixes := request:get-attribute("$templates:prefixes")
    return
        templates:process(doc($path), $prefixes, $model)
};

declare function templates:surround($node as node(), $params as element(parameters)?, $model as item()*) {
    let $with := $params/param[@name = "with"]/@value
    let $template := theme:resolve(request:get-attribute("exist:prefix"), request:get-attribute("exist:root"), $with)
    let $log := util:log("DEBUG", ("template: ", $template))
    let $at := $params/param[@name = "at"]/@value
    let $path := concat($config:app-root, "/", $template)
    let $merged := templates:process-surround(doc($template), $node, $at)
    let $prefixes := request:get-attribute("$templates:prefixes")
    return
        templates:process($merged, $prefixes, $model)
};

declare function templates:process-surround($node as node(), $content as node(), $at as xs:string) {
    typeswitch ($node)
        case document-node() return
            for $child in $node/node() return templates:process-surround($child, $content, $at)
        case element() return
            if ($node/@id eq $at) then
                element { node-name($node) } {
                    $node/@*, $content/node()
                }
            else
                element { node-name($node) } {
                    $node/@*, for $child in $node/node() return templates:process-surround($child, $content, $at)
                }
        default return
            $node
};

declare function templates:if-parameter-set($node as node(), $params as element(parameters), $model as item()*) as node()* {
    let $paramName := $params/param[@name = "param"]/@value/string()
    let $param := request:get-parameter($paramName, ())
    return
        if ($param and string-length($param) gt 0) then
            let $prefixes := request:get-attribute("$templates:prefixes")
            for $child in $node/node()
            return
                templates:process($child, $prefixes, $model)
        else
            ()
};

declare function templates:if-parameter-unset($node as node(), $params as element(parameters), $model as item()*) as node()* {
    let $paramName := $params/param[@name = "param"]/@value/string()
    let $param := request:get-parameter($paramName, ())
    return
        if (not($param) or string-length($param) eq 0) then
            $node
        else
            ()
};

declare function templates:load-source($node as node(), $params as element(parameters), $model as item()*) as node()* {
    let $href := $node/@href/string()
    let $context := request:get-context-path()
    return
        <a href="{$context}/eXide/index.html?open={$config:app-root}/{$href}" target="eXide">{$node/node()}</a>
};

(:~
    Processes input and select form controls, setting their value/selection to
    values found in the request - if present.
 :)
declare function templates:form-control($node as node(), $params as element(parameters), $model as item()*) as node()* {
    typeswitch ($node)
        case element(input) return
            let $name := $node/@name
            let $value := request:get-parameter($name, ())
            return
                if ($value) then
                    element { node-name($node) } {
                        $node/@* except $node/@value,
                        attribute value { $value },
                        $node/node()
                    }
                else
                    $node
        case element(select) return
            let $value := request:get-parameter($node/@name/string(), ())
            return
                element { node-name($node) } {
                    $node/@* except $node/@class,
                    for $option in $node/option
                    return
                        <option>
                        {
                            $option/@*,
                            if ($option/@value = $value) then
                                attribute selected { "selected" }
                            else
                                (),
                            $option/node()
                        }
                        </option>
                }
        default return
            $node
};