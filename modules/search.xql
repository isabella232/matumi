module namespace search="http://exist-db.org/xquery/search";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";
import module namespace func="http://exist-db.org/encyclopedia/functions" at "func.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic";
import module namespace dict="http://exist-db.org/xquery/dict" at "dict2html.xql";

declare option exist:serialize "method=xml media-type=application/xml";

declare variable $search:FIELDS :=
    <fields>
        <field name="Lemma">$context//tei:form[ft:query(tei:orth, "$q")] union
            $context//tei:div[@type = "entry"]/tei:head[ft:query(., "$q")]</field>
        <field name="Name">func:expand-name($context, "$q")</field>
        <field name="Term">$context//tei:term[ft:query(., "$q")]</field>
        <field name="Text">$context//tei:p[ft:query(., "$q")]</field>
        <field name="Key">func:find-by-key($context, "$q")</field>
    </fields>
;

declare variable $search:COLORS :=
    <colors>
        <color type="place">#FF7800</color>
        <color type="person">#864E00</color>
        <color type="people">#864E00</color>
        <color type="period">#FF0DD4</color>
    </colors>
;

declare variable $search:CONFIG :=
    <config width="40" table="yes"/>
;

declare variable $search:FACETS := 
    let $query := request:get-parameter("q", ())
    return
        if ($query) then
            let $facet := request:get-parameter("facet", ())
            return
                ( session:set-attribute("matumi:facets", $facet), $facet )
        else
            session:get-attribute("matumi:facets")
;

declare function search:apply-facets($input as element()*, $facets as xs:string*) {
    if (empty($facets)) then
        $input
    else
        search:apply-facets($input[ancestor-or-self::tei:p//*[@key = $facets[1]]], subsequence($facets, 2))
};

declare function search:query-to-session() {
    let $query :=
        <query>
            <field name="{request:get-parameter('field', ())}">{request:get-parameter("q", ())}</field>
        </query>
    return
        (session:create(), session:set-attribute("matumi:query", $query))
};

declare function search:query-form() {
    let $queryFromSession := session:get-attribute("matumi:query")
    return
        <tr>
            <td>
                <select name="field">
                {
                    let $value := (request:get-parameter("field", ()), $queryFromSession/field/@name)[1]
                    for $field in $search:FIELDS/field/@name/string()
                    return
                        <option>
                        { if ($field eq $value) then attribute selected { "selected"} else () }
                        { $field }
                        </option>
                }
                </select>
            </td>
            <td>
                <input name="q" size="50"
                    value="{(request:get-parameter('q', ()), $queryFromSession/field/string())[1]}"/>
                <button type="reset">Clear</button>
            </td>
        </tr>
};

declare function search:query() as xs:string {
    let $field := request:get-parameter("field", ())
    let $queryStr := request:get-parameter("q", ())
    let $expr := $search:FIELDS/field[@name = $field]
    let $expandedExpr := replace($expr, "\$q", $queryStr)
    return
        ($expandedExpr, search:query-to-session())
};

declare function search:filter($node as node(), $mode as xs:string) as item()? {
    if ($mode eq "before") then 
        concat($node, ' ')
    else 
        concat(' ', $node)
};

declare function search:display-result($node as element(), $xpath as xs:string) {
    if (local-name($node) = ('name', 'term', 'p')) then
        let $callback := util:function(xs:QName("search:filter"), 2)
        let $config :=
            <config width="40" table="yes"
                link="entry.html?doc={document-uri(root($node))}&amp;qu={$xpath}&amp;node={util:node-id($node)}"/>
        let $block := $node/ancestor-or-self::tei:p
        return
            if ($block) then
                kwic:summarize($block, $config, $callback)
            else
                ()
    else
        let $documentURI := document-uri(root($node))
        return
            typeswitch ($node)
                case element(tei:form) return
                    <tr>
                        <td><a href="entry.html?doc={$documentURI}&amp;qu={$xpath}&amp;node={util:node-id($node)}">{$node/tei:orth/string()}</a></td>
                        <td>{dict:process($documentURI, $node/../tei:sense[1]/tei:def, ())}</td>
                    </tr>
                case element(tei:head) return
                    <tr>
                        <td><a href="entry.html?doc={$documentURI}&amp;qu={$xpath}&amp;node={util:node-id($node)}">{$node/string()}</a></td>
                        <td>{dict:process($documentURI, $node/../tei:div/tei:p[1]/tei:gloss[1], ())}</td>
                    </tr>
                default return
                    ()
};

declare function search:name-facet($root as element()*, $type as xs:string) {
    <div class="facet">
        <h3 class="{$type}">{dict:capitalize-first($type)}</h3>
        <ul>
        {
            let $names :=
                distinct-values(
                    for $name in $root//tei:name[@type = $type]
                    return
                        $name/@key
                )
            for $name in $names order by $name
            return
                <li>
                    <input type="checkbox" name="facet" class="facet-check" value="{$name}"
                        title="Mark to restrict search">
                        {if (exists(index-of($search:FACETS, $name))) then attribute checked { "checked" } else ()}
                    </input>
                    {translate(replace($name, "^.*/([^/]+)", "$1"), "_", " ")}
                    <span class="facet-links">
                        <a href="{$name}" target="_new">
                            DBpedia
                        </a>
                        |
                        <a class="key-search" 
                            href="{$name}" target="_new">
                            New Search
                        </a>
                    </span>
                </li>
        }
        </ul>
    </div>
};

declare function search:facets($root as element()*) {
    <div id="facets">
        <a href="#" id="clear-facets">Clear all</a>
        {
            for $facet in distinct-values($root//tei:name/@type)
            order by $facet
            return search:name-facet($root, $facet)
        }
    </div>
};

declare function search:do-search($xpath as xs:string) {
    let $context := collection($config:app-root)
    let $result :=
        search:apply-facets(util:eval($xpath), $search:FACETS)
    return (
        session:set-attribute("matumi:results", $result),
        session:set-attribute("matumi:xpath", $xpath),
        $result
    )
};

declare function search:show-facets($result) {
    search:facets($result/ancestor-or-self::tei:p)
};

declare function search:search() {
    let $session := session:create()
    let $query := request:get-parameter("q", ())
    let $xpath := if ($query) then search:query() else session:get-attribute("matumi:xpath")
    let $results :=
        if ($query) then
            search:do-search($xpath)
        else
            session:get-attribute("matumi:results")
    return
        $results
};

declare function search:show-results($results) {
    let $xpath := session:get-attribute("matumi:xpath")
    let $rows :=
        for $result in $results
        order by ft:score($result)
        return
            search:display-result($result, $xpath)
    return
        <div>
            <p id="navbar">Query Results: {count($rows)} matches in {count($results)} paragraphs.</p>
            <div id="results">
                <div id="results-container">
                    <table class="kwic">
                    {
                        $rows
                    }
                    </table>
                </div>
            </div>
        </div>
};