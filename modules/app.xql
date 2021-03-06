xquery version "3.0";

module namespace app="http://exist-db.org/apps/appblueprint/templates";

import module namespace sarit="http://exist-db.org/xquery/sarit";
import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace config="http://exist-db.org/apps/appblueprint/config" at "config.xqm";
import module namespace metadata = "http://exist-db.org/ns/sarit/metadata/" at "metadata.xqm";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace tei-to-html="http://exist-db.org/xquery/app/tei2html" at "tei2html.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";

declare default collation "?lang=hi-IN";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace h="http://www.w3.org/1999/xhtml";
declare namespace functx="http://www.functx.com";

declare variable $app:devnag2roman := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "devnag2roman"];
declare variable $app:roman2devnag := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "roman2devnag"];
declare variable $app:roman2devnag-search := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "roman2devnag-search"];
declare variable $app:expand := doc($config:app-root || "/modules/transliteration-rules.xml")//*[@id = "expand"];
declare variable $app:iast-char-repertoire-negation := '[^aābcdḍeĕghḥiïījklḷḹmṁṃnñṅṇoŏprṛṝsśṣtṭuüūvy0-9\s]';

declare variable $app:EXIDE := 
    let $pkg := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
    let $appLink :=
        if ($pkg) then
            substring-after(util:collection-name($pkg), repo:get-root())
        else
            ()
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "index.html"), "/")
    return
        replace($path, "/+", "/");
    
(:~
 : Process navbar links to cope with browsing.
 :)
(:template function in template.html:)
declare
    %templates:wrap
function app:nav-set-active($node as node(), $model as map(*)) {
    let $path := request:get-attribute("$exist:path")
    let $res := request:get-attribute("$exist:resource")
    for $li in $node/h:li
    let $link := $li/h:a
    let $href := $link/@href
    return
        element { node-name($li) } {
            if ($href = $res or ($href = "works/" and starts-with($path, "/works/"))) then
                attribute class { "active" }
            else
                (),
            <h:a>
            {
                $link/@* except $link/@href,
                attribute href {
                    if ($link/@href = "works/" and starts-with($path, "/works/")) then
                        "."
                    else if (starts-with($path, ("/works/", "/docs/"))) then
                        "../" || $link/@href
                    else
                        $link/@href
                },
                $link/node()
            }
            </h:a>,
            $li/h:ul
        }
};

declare function functx:substring-before-if-contains
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string? {

   if (contains($arg,$delim))
   then substring-before($arg,$delim)
   else $arg
 } ;
 
declare function functx:substring-after-if-contains
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string? {

   if (contains($arg,$delim))
   then substring-after($arg,$delim)
   else $arg
 } ;
 
 declare %private function functx:substring-before-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {

   if (matches($arg, functx:escape-for-regex($delim)))
   then replace($arg,
            concat('^(.*)', functx:escape-for-regex($delim),'.*'),
            '$1')
   else ''
 } ;

(:modified by applying functx:escape-for-regex() :)
declare %private function functx:number-of-matches 
  ( $arg as xs:string? ,
    $pattern as xs:string )  as xs:integer {
       
   count(tokenize(functx:escape-for-regex(functx:escape-for-regex($arg)),functx:escape-for-regex($pattern))) - 1
 } ;

declare %private function functx:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;
 
(:~
 : List SARIT works
 :)
(:template function in browse.html:)
declare 
    %templates:wrap
function app:list-works($node as node(), $model as map(*)) {
    map {
        "works" :=
            for $work in collection($config:remote-data-root)/tei:TEI
            order by app:work-title($work)
            return
                $work
    }
};

(:template function in view-play.html:)
declare
    %templates:wrap
function app:work($node as node(), $model as map(*), $id as xs:string) {
    let $work := app:load(collection($config:remote-data-root), $id)
    return
        map { "work" := $work[1] }
};

declare %private function app:load($context as node()*, $id as xs:string) {
    (:$context is tei:TEI when loading a document from the TOC and when loading a hit from tei:text; when loading a hit from tei:teiHeader, it is tei:teiHeader.:)
    let $work := if ($context instance of element(tei:teiHeader)) then $context else $context//id($id)
    return
        if ($work) then
            $work
        else 
            if (matches($id, "_[p\d\.]+$")) then
            let $analyzed := analyze-string($id, "^(.*)_([^_]+)$")
            let $docName := $analyzed//fn:group[@nr = 1]/text()
            let $doc := doc($config:remote-data-root || "/" || $docName)
            let $nodeId := $analyzed//fn:group[@nr = 2]/string()
            return
                if (starts-with($nodeId, "p")) then
                    let $page := number(substring-after($nodeId, "p"))
                    return
                        ($doc//tei:pb)[$page]
                else
                    util:node-by-id($doc, $nodeId)
        else doc($config:remote-data-root || "/" || $id)/tei:TEI
};

(:template function in view-work.html:)
declare function app:header($node as node(), $model as map(*)) {
    tei-to-html:render($model("work")/tei:teiHeader)
};

(:You can always see three levels: the current level, is siblings, its parent and its children. 
This means that you can always go up and down (and sideways).
One could leave out or elide the siblings. :)
(:template function in view-work.html:)
declare 
    %templates:default("full", "false")
function app:outline($node as node(), $model as map(*), $full as xs:boolean) {
    let $position := $model("work")
    let $root := if ($full) then $position/ancestor-or-self::tei:TEI else $position
    let $long := $node/@data-template-details/string()
    let $work := $root/ancestor-or-self::tei:TEI
    return
        if (
            exists($work/tei:text/tei:front/tei:titlePage) or 
            exists($work/tei:text/tei:front/tei:div) or 
            exists($work/tei:text/tei:body/tei:div) or 
            exists($work/tei:text/tei:back/tei:div)
           ) 
        then (
            <ul class="contents">{
                typeswitch($root)
                    case element(tei:div) return
                        (:if it is not the whole work:)
                        app:generate-toc-from-div($root, $long, $position) 
                    case element(tei:titlePage) return
                        (:if it is not the whole work:)
                        app:generate-toc-from-div($root, $long, $position)
                    default return
                        (:if it is the whole work:)
                        (
                        if ($work/tei:text/tei:front/tei:titlePage, $work/tei:text/tei:front/tei:div)
                        then
                            <div class="text-front">
                            <h6>Front Matter</h6>
                            {for $div in 
                                (
                                $work/tei:text/tei:front/tei:titlePage, 
                                $work/tei:text/tei:front/tei:div 
                                )
                            return app:toc-div($div, $long, $position, 'list-item')
                            }</div>
                            else ()
                        ,
                        <div class="text-body">
                        <h6>{if ($work/tei:text/tei:front/tei:titlePage, $work/tei:text/tei:front/tei:div, $work/tei:text/tei:back/tei:div) then 'Text' else ''}</h6>
                        {for $div in 
                            (
                            $work/tei:text/tei:body/tei:div 
                            )
                        return app:toc-div($div, $long, $position, 'list-item')
                        }</div>
                        ,
                        if ($work/tei:text/tei:back/tei:div)
                        then
                            <h6 class="text-back">
                            <h6>Back Matter</h6>
                            {for $div in 
                                (
                                $work/tei:text/tei:back/tei:div 
                                )
                            return app:toc-div($div, $long, $position, 'list-item')
                            }</h6>
                        else ()
                        )
            }</ul>
        ) else ()
};

declare %private function app:generate-toc-from-div($root, $long, $position) {
    (:if it has divs below itself:)
    <li>{
    if ($root/tei:div) then
        (
        if ($root/parent::tei:div) 
        (:show the parent:)
        then app:toc-div($root/parent::tei:div, $long, $position, 'no-list-item') 
        (:NB: this creates an empty <li> if there is no div parent:)
        (:show nothing:)
        else ()
        ,
        for $div in $root/preceding-sibling::tei:div
        return app:toc-div($div, $long, $position, 'list-item')
        ,
        app:toc-div($root, $long, $position, 'list-item')
        ,
        <ul>
            {
            for $div in $root/tei:div
            return app:toc-div($div, $long, $position, 'list-item')
            }
        </ul>
        ,
        for $div in $root/following-sibling::tei:div
        return app:toc-div($div, $long, $position, 'list-item')
        )
    else
    (
        (:if it is a leaf:)
        (:show its parent:)
        app:toc-div($root/parent::tei:div, $long, $position, 'no-list-item')
        ,
        (:show its preceding siblings:)
        <ul>
            {
            for $div in $root/preceding-sibling::tei:div
            return app:toc-div($div, $long, $position, 'list-item')
            ,
            (:show itself:)
            (:NB: should not have link:)
            app:toc-div($root, $long, $position, 'list-item')
            ,
            (:show its following siblings:)
            for $div in $root/following-sibling::tei:div
            return app:toc-div($div, $long, $position, 'list-item')
            }
        </ul>
        )
       }</li>
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare %private function app:generate-toc-from-divs($node, $current as element()?, $long as xs:string?) {
    if ($node/tei:div) 
    then
        <ul style="display: none">{
            for $div in $node/tei:div
            return app:toc-div($div, $long, $current, 'list-item')
        }</ul>
    else ()
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare %private function app:derive-title($div) {
    typeswitch ($div)
        case element(tei:div) return
            let $n := $div/@n/string()
            let $title := 
                (:if the div has a header:)
                if ($div/tei:head) 
                then
                    concat(
                        if ($n) then concat($n, ': ') else ''
                        ,
                        string-join(
                            for $node in $div/tei:head/node() 
                            return data($node)
                        , ' ')
                    )
                else
                    let $type := $div/@type
                    let $data := app:generate-title($div//text(), 0)
                    return
                        (:otherwise, take part of the text itself:)
                        if (string-length($data) gt 0) 
                        then
                            concat(
                                if ($type) 
                                then concat('[', $type/string(), '] ') 
                                else ''
                            , substring($data, 1, 25), '…') 
                        else concat('[', $type/string(), ']')
            return $title
        case element(tei:titlePage) return
            tei-to-html:titlePage($div, <options/>)
        default return
            ()
};

declare %private function app:generate-title($nodes as text()*, $length as xs:int) {
    if ($nodes) then
        let $text := head($nodes)
        return
            if ($length + string-length($text) > 25) then
                (substring($text, 1, 25 - $length) || "…")
            else
                ($text || app:generate-title(tail($nodes), $length + string-length($text)))
    else
        ()
};

(:based on Joe Wicentowski, http://digital.humanities.ox.ac.uk/dhoxss/2011/presentations/Wicentowski-XMLDatabases-materials.zip:)
declare %private function app:toc-div($div, $long as xs:string?, $current as element()?, $list-item as xs:string?) {
    let $div-id := $div/@xml:id/string()
    let $div-id := 
        if ($div-id) then $div-id else util:document-name($div) || "_" || util:node-id($div)
    return
        if ($list-item eq 'list-item')
        then
            if (count($div/ancestor::tei:div) < 2)
            then
                <li class="{if ($div is $current) then 'current' else 'not-current'}">
                    {
                        if ($div/tei:div and count($div/ancestor::tei:div) < 1) then
                            <a href="#" class="toc-toggle"><i class="glyphicon glyphicon-plus"/></a>
                        else
                            ()
                    }
                    <a href="{$div-id}.html" class="toc-link">{app:derive-title($div)}</a> 
                    {if ($long eq 'yes') then app:generate-toc-from-divs($div, $current, $long) else ()}
                </li>
            else ()
        else
            <a href="{$div-id}.html">{app:derive-title($div)}</a> 
};

(:~
(:template function in browse.html:)
 :)
declare function app:work-title($node as node(), $model as map(*), $type as xs:string?) {
    let $suffix := if ($type) then "." || $type else ()
    let $work := $model("work")/ancestor-or-self::tei:TEI
    (:all works have an @xml:id:)
    return
        <a xmlns="http://www.w3.org/1999/xhtml" href="{$node/@href}{$work/@xml:id}{$suffix}">{ app:work-title($work) }</a>
};

declare %public function app:work-title($work as element(tei:TEI)?) {
    let $main-title := $work/*:teiHeader/*:fileDesc/*:titleStmt/*:title[@type eq 'main']/text()
    let $main-title := if ($main-title) then $main-title else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1]/text()
    let $commentary-titles := $work/*:teiHeader/*:fileDesc/*:titleStmt/*:title[@type eq 'sub'][@subtype eq 'commentary']/text()
    return
        if ($commentary-titles)
        then tei-to-html:serialize-list($commentary-titles)
        else $main-title
};

declare %public function app:work-author($work as element(tei:TEI)?) {
    let $work-commentators := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'commentator']/text()
    let $work-authors := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'base-author']/text()
    let $work-authors := if ($work-authors) then $work-authors else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author/text()
    let $work-authors := if ($work-commentators) then $work-commentators else $work-authors
    let $work-authors := if ($work-authors) then tei-to-html:serialize-list($work-authors) else ()
    return 
        $work-authors    
};

(:template function in browse.html:)
declare 
    %templates:wrap
function app:checkbox($node as node(), $model as map(*), $target-texts as xs:string*) {
    let $id := $model("work")/@xml:id/string()
    return (
        attribute { "value" } {
            $id
        },
        if ($id = $target-texts) then
            attribute checked { "checked" }
        else
            ()
    )
};

(:template function in browse.html:)
declare function app:work-author($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $work-commentators := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'commentator']/text()
    let $work-authors := $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[@role eq 'base-author']/text()
    let $work-authors := if ($work-authors) then $work-authors else $work/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author/text()
    let $work-authors := if ($work-commentators) then $work-commentators else $work-authors
    let $work-authors := if ($work-authors) then tei-to-html:serialize-list($work-authors) else ()
    return 
        $work-authors    
};

(:template function in browse.html:)
declare function app:work-lang($node as node(), $model as map(*)) {
    let $work := $model("work")/ancestor-or-self::tei:TEI
    let $script := $work//tei:text/@xml:lang
    let $script := if ($script eq 'sa-Latn') then 'IAST' else 'Devanagari'
    let $auto-conversion := $work//tei:revisionDesc/tei:change[@type eq 'conversion'][@subtype eq 'automatic'] 
    return 
        concat($script, if ($auto-conversion) then ' (automatically converted)' else '')  
};

declare function app:statistics($node as node(), $model as map(*)) {
        "SARIT currently contains "|| $metadata:metadata/metadata:number-of-xml-works ||" text files (TEI-XML) of " || $metadata:metadata/metadata:size-of-xml-works || " XML (" || $metadata:metadata/metadata:number-of-pdf-pages || " pages in PDF format)."
};

(:template function in browse.html:)
declare function app:epub-link($node as node(), $model as map(*)) {
    let $id := $model("work")/@xml:id/string()
    return
        <a xmlns="http://www.w3.org/1999/xhtml" href="{$node/@href}{$id}.epub">{ $node/node() }</a>
};

(:template function in browse.html:)
declare function app:pdf-link($node as node(), $model as map(*)) {
    let $id := $model("work")/@xml:id/string()
    let $uuid := util:uuid()
    return
        <a class="pdf-link" xmlns="http://www.w3.org/1999/xhtml" 
            data-token="{$uuid}" href="{$node/@href}{$id}.pdf?token={$uuid}">{ $node/node() }</a>
};

(:template function in browse.html:)
declare function app:zip-link($node as node(), $model as map(*)) {
    let $file := util:document-name($model("work"))
    let $downloadPath := request:get-scheme() ||"://" || request:get-server-name() || ":" || request:get-server-port() || substring-before(request:get-effective-uri(),"/db/apps/sarit/modules/view.xql") || $config:remote-download-root || "/" || substring-before($file,".xml") || ".zip"
    return
        <a xmlns="http://www.w3.org/1999/xhtml" href="{$downloadPath}">{ $node/node() }</a>
};

(:template function in browse.html:)
declare function app:xml-link($node as node(), $model as map(*)) {
    let $doc-path := document-uri(root($model("work")))
    let $eXide-link := $app:EXIDE || "?open=" || $doc-path
    let $rest-link := '/exist/rest' || $doc-path
    return
        if ($app:EXIDE)
        then 
            <a xmlns="http://www.w3.org/1999/xhtml" href="{$eXide-link}" 
                target="eXide" class="eXide-open" data-exide-open="{$doc-path}">{ $node/node() }</a>
        else 
            <a xmlns="http://www.w3.org/1999/xhtml" href="{$rest-link}" target="_blank">{ $node/node() }</a>
};

(:template function in view-work.html:)
declare function app:copy-params($node as node(), $model as map(*)) {
    element { node-name($node) } {
        $node/@* except $node/@href,
        attribute href {
            let $link := $node/@href
            let $params :=
                string-join(
                    for $param in request:get-parameter-names()
                    for $value in request:get-parameter($param, ())
                    return
                        $param || "=" || $value,
                    "&amp;"
                )
            return
                $link || "?" || $params
        },
        $node/node()
    }
};

(:template function in browse.html:)
declare function app:work-authors($node as node(), $model as map(*)) {
    let $authors := distinct-values(collection($config:remote-data-root)//tei:fileDesc/tei:titleStmt/tei:author)
    let $authors := for $author in $authors order by translate($author, 'ĀŚ', 'AS') return $author 
    let $control := 
        <select multiple="multiple" name="work-authors" class="form-control">
            <option value="all" selected="selected">In Texts By Any Author</option>
            {for $author in $authors
            return <option value="{$author}">{$author}</option>
            }
        </select>
    return
        templates:form-control($control, $model)
};

(:template function in view-play.html:)
declare 
    %templates:wrap
function app:navigation($node as node(), $model as map(*)) {
    let $div := $model("work")
    let $parent := $div/ancestor::tei:div[not(*[1] instance of element(tei:div))][1]
    let $prevDiv := $div/preceding::tei:div[1]
    let $prevDiv := app:get-previous(if ($parent and $div/.. >> $prevDiv) then $div/.. else $prevDiv)
    let $nextDiv := app:get-next($div)
(:        ($div//tei:div[not(*[1] instance of element(tei:div))] | $div/following::tei:div)[1]:)
    let $work := $div/ancestor-or-self::tei:TEI
    return
        map {
            "previous" := $prevDiv,
            "next" := $nextDiv,
            "work" := $work,
            "div" := $div
        }
};

declare %private function app:get-next($div as element()) {
    if ($div/tei:div) then
        if (count(($div/tei:div[1])/preceding-sibling::*) < 5) then
            app:get-next($div/tei:div[1])
        else
            $div/tei:div[1]
    else
        $div/following::tei:div[1]
};

declare %private function app:get-previous($div as element()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
        $div
        else
            if (
                empty($div/preceding-sibling::tei:div)  (: if it is the first div in a section :)
                and count($div/preceding-sibling::*) < 5 (: if there are less than 5 elements before it :)
                and $div/.. instance of element(tei:div) (: if its parent is a div :)
            ) then
                (: then there is too little content to display, so we try if its parent is better. :)
                app:get-previous($div/..)
            else
                $div
};

(:template function in view-play.html, commented out:)
(:declare
    %templates:wrap
function app:breadcrumbs($node as node(), $model as map(*)) {
    let $ancestors := $model("div")/ancestor-or-self::tei:div
    for $ancestor in $ancestors
    let $id := $ancestor/@xml:id
    return
        <li><a href="{$id}.html">{app:derive-title($ancestor)}</a></li>
};:)

(:template function in view-play.html:)
declare
    %templates:wrap
function app:navigation-title($node as node(), $model as map(*)) {
    let $id :=
        if ($model("work")/@xml:id) then
            $model("work")/@xml:id
        else
            util:document-name($model("work")) || "_" || util:node-id($model("work"))
    return
        element { node-name($node) } {
            attribute href { $id },
            $node/@* except $node/@href,
            app:work-title($model('work'))
        }
};

(:template function in view-play.html:)
declare function app:navigation-link($node as node(), $model as map(*), $direction as xs:string) {
    if ($model($direction)) then
        element { node-name($node) } {
            $node/@* except $node/@href,
            let $id := 
                if ($model($direction)/@xml:id) then
                    $model($direction)/@xml:id/string()
                else
                    util:document-name($model($direction)) || "_" || util:node-id($model($direction))
            return
                attribute href { $id || ".html" },
            $node/node()
        }
    else
        '&#xA0;' (:hack to keep "Next" from dropping into the hr when there is no "Previous":) 
};

(:template function in view-play.html:)
declare 
    %templates:default("action", "browse")
function app:view($node as node(), $model as map(*), $action as xs:string) {
    if ($action eq 'browse')
    then
        for $div in $model("work")
        return 
            <div xmlns="http://www.w3.org/1999/xhtml" class="play">
            { tei-to-html:recurse($div, <options><param name="div-type" value="{$div/@type}" /></options>) }
            </div>
    else
        let $lucene-query := session:get-attribute("apps.sarit.lucene-query")
        let $ngram-query := session:get-attribute("apps.sarit.ngram-query")
        return
            if (string-length(string-join($lucene-query)))
            then app:lucene-view($node, $model, $lucene-query)
            else
                if (string-length(string-join($ngram-query)))
                then app:ngram-view($node, $model, $ngram-query)
                else ()
};

declare %private function app:lucene-view($node as node(), $model as map (*), $query as xs:string+)
{
    let $query := string-join($query, ' OR ')
    (:can there be more than one div here?:)
    for $div in $model("work")
    let $div :=
        if ($query) then
            $div[ft:query(., $query)]
        else
            $div
    (:can there be more than one div here?:)
    let $view := app:get-content($div[1])
    let $view := util:expand($view, "add-exist-id=all")
    return
        <div xmlns="http://www.w3.org/1999/xhtml" class="play">
        { tei-to-html:recurse($view, <options/>) }
        </div>
};

declare %private function app:ngram-view($node as node(), $model as map (*), $query as xs:string+)
{
    (:can there be more than one div here?:)
    for $div in $model("work")
    let $view := app:recursive-ngram-search(distinct-values($query), $div)
    return
        <div xmlns="http://www.w3.org/1999/xhtml" class="play">
        { tei-to-html:recurse($view, <options><param name="div-type" value="{$view/@type}" /></options>) }
        </div>
};

(: the idea is to get exist:match on all hits, but ngram search is lazy and marks up only the first match (whereas lucene search continues marking up even after hits have been found. :)
declare %private function app:recursive-ngram-search($queries as xs:string+, $div as element()) as element() {
    let $head := head($queries)
    let $tail := tail($queries)
    let $div-match := $div[ngram:wildcard-contains(., $head)]
    let $div-match := util:expand($div-match, "add-exist-id=all")
    let $div := 
        if ($div-match//exist:match) 
        (:can there be more than one div here?:)
        then app:get-content($div-match[1]) 
        else $div
    return
        if (empty($tail))
        then $div
        else app:recursive-ngram-search($tail, $div)
};

declare %private function app:get-content($div as element()) {
    if ($div instance of element(tei:teiHeader)) then 
        $div
    else
        if ($div instance of element(tei:div)) then
            if ($div/tei:div) then
                if (count(($div/tei:div[1])/preceding-sibling::*) < 5) then
                    let $child := $div/tei:div[1]
                    return
                        element { node-name($div) } {
                            $div/@*,
                            $child/preceding-sibling::*,
                            app:get-content($child)
                        }
                else
                    element { node-name($div) } {
                        $div/@*,
                        $div/tei:div[1]/preceding-sibling::*
                    }
            else
                $div
        else $div
};

(:~
    
:)
(:~
: Execute the query. The search results are not output immediately. Instead they
: are passed to nested templates through the $model parameter.
:
: @author Wolfgang M. Meier
: @author Jens Østergaard Petersen
: @param $node 
: @param $model
: @param $query The query string. This string is transformed into a <query> element containing one or two <bool> elements in a Lucene query and it is transformed into a sequence of one or two query strings in an ngram query. The first <bool> and the first string contain the query as input and the second the query as transliterated into Devanagari or IAST as determined by $query-scripts. One <bool> and one query string may be empty.
: @param $index The index against which the query is to be performed, as the string "ngram" or "lucene".
: @param $tei-target A sequence of one or more targets within a TEI document, the tei:teiHeader or tei:text.
: @param $work-authors A sequence of the string "all" or of the xml:ids of the documents associated with the selected authors.
: @param $query-scripts A sequence of the string "all" or of the values "sa-Latn" or "sa-Deva", indicating whether or not the user wishes to transliterate the query string.
: @param $target-texts A sequence of the string "all" or of the xml:ids of the documents selected.

: @return The function returns a map containing the $hits, the $query, and the $query-scope. The search results are output through the nested templates, app:hit-count, app:paginate, and app:show-hits.
:)
(:template function in search.html:)
declare 
    %templates:default("index", "ngram")
    %templates:default("tei-target", "tei-text")
    %templates:default("query-scope", "narrow")
    %templates:default("work-authors", "all")
    %templates:default("query-scripts", "all")
    %templates:default("target-texts", "all")
    %templates:default("bool", "new")
function app:query($node as node()*, $model as map(*), $query as xs:string?, $index as xs:string, $tei-target as xs:string+, $query-scope as xs:string, $work-authors as xs:string+, $query-scripts as xs:string, $target-texts as xs:string+, $bool as xs:string) as map(*) {
    (:remove any ZERO WIDTH NON-JOINER from the query string:)
    let $query := lower-case(translate(normalize-space($query), "&#8204;", ""))
    (:based on which index the user wants to query against, the query string is dispatchted to separate functions. Both return empty if there is no query string.:)
    let $queries := app:expand-query($query, $query-scripts)
    (:both lucene queries and ngram queries are passed around as sequences of strings, but after expansion lucene queries have to be wrapped in slashes to trigger regex mode:)
    let $queries := 
        if ($index eq 'ngram')
        then $queries
        else
            for $query in $queries
            return
                if (contains($query, '[') and not(starts-with(normalize-space($query), "/") and ends-with(normalize-space($query), "/")))
                then "/" || $query || "/"
                else $query
    (:this joins the latest lucene query with OR if it has been expanded - this OR does not have anything to do with boolean searches:)
    let $queries := 
        if ($index eq 'ngram')
        then $queries
        else string-join($queries, ' OR ')
    return
        (:If there is no query string, fill up the map with existing values:)
        if (empty($queries))
        then
            map {
                "hits" := session:get-attribute("apps.sarit.hits"),
                "index" := session:get-attribute("apps.sarit.index"),
                "ngram-query" := session:get-attribute("apps.sarit.ngram-query"),
                "lucene-query" := session:get-attribute("apps.sarit.lucene-query"),
                "scope" := $query-scope (:NB: what about the other arguments?:)
            }
        else
            (:Otherwise, perform the query.:)
            (:First, which documents to query against has to be found out. Users can either make no selections in the list of documents, passing the value "all", or they can select individual document, passing a sequence of their xml:ids in $target-texts. Users can also select documents based on their authors. If no specific authors are selected, the value "all" is passed in $work-authors, but if selections have been made, a sequence of their xml:ids is passed. :)
            (:$target-texts will either have the value 'all' or contain a sequence of document xml:ids.:)
            let $target-texts := 
                (:("target-texts", "all")("work-authors", "all"):)
                (:If no texts have been selected and no authors have been selected, search in all texts:)
                if ($target-texts = 'all' and $work-authors = 'all')
                then 'all' 
                else
                    (:("target-texts", "sequence of document xml:ids")("work-authors", "all"):)
                    (:If one or more texts have been selected, but no authors, search in selected texts:)
                    if ($target-texts != 'all' and $work-authors = 'all')
                    then $target-texts
                    else 
                        (:("target-texts", "all")("work-authors", "sequence of document xml:ids"):)
                        (:If no texts, but one or more authors have been selected, search in texts selected by author:)
                        if ($target-texts = 'all' and $work-authors != 'all')
                        then distinct-values(collection($config:remote-data-root)//tei:TEI[tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author = $work-authors]/@xml:id)
                        else
                            (:("target-texts", "sequence of document xml:ids")("work-authors", "sequence of text xml:ids"):)
                            (:If one or more texts and more authors have been selected, search in the union of selected texts and texts selected by authors:)
                            if ($target-texts != 'all' and $work-authors != 'all')
                            then distinct-values(($target-texts, collection($config:remote-data-root)//tei:TEI[tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author = $work-authors]/@xml:id))
                            else ()
            (:After it has been determined which documents to query, we have to find out which document parts are targeted, the query "context". There are two parts, the text element ("tei-text") and the TEI header ("tei-header"). It is possible to select multiple contexts:)
            let $context := 
                (:If all documents have been selected for query, set the context as $config:remote-data-root:)
                if ($target-texts = 'all')
                then 
                    (:if there are two tei-targets, set the context below $config:remote-data-root to the common parent of tei-text and tei-header, the document element TEI, otherwise set it to tei-text and tei-header, respectively.:)
                    if (count($tei-target) eq 2)
                    then collection($config:remote-data-root)/tei:TEI
                    else
                        if ($tei-target = 'tei-text')
                        then collection($config:remote-data-root)/tei:TEI/tei:text
                        else 
                            if ($tei-target = 'tei-header')
                            then collection($config:remote-data-root)/tei:TEI/tei:teiHeader
                            else ()
                else
                    (:If individual documents have been selected for query, use the sequence of xml:ids in $target-texts to filter the documents below $config:remote-data-root:)
                    if (count($tei-target) eq 2)
                    (:if there are two tei-targets, set the context below $config:remote-data-root to the common parent of tei-text and tei-header, the document element TEI, otherwise set it to tei-text and tei-header, respectively.:)
                    then collection($config:remote-data-root)//tei:TEI[@xml:id = $target-texts]
                    else 
                        if ($tei-target = 'tei-text')
                        then collection($config:remote-data-root)//tei:TEI[@xml:id = $target-texts]/tei:text
                        else 
                            if ($tei-target = 'tei-header')
                            then collection($config:remote-data-root)//tei:TEI[@xml:id = $target-texts]/tei:teiHeader
                            else ()
            (: Here the actual query commences. This is split into two parts, the first for a Lucene query and the second for an ngram query. :)
            (:The query passed to a Lucene query in ft:query is a string containing one or two queries joined by an OR. The queries contain the original query and the transliterated query, as indicated by the user in $query-scripts.:)
            let $hits :=
                if ($index eq 'lucene')
                then
                    (:If the $query-scope is narrow, query the elements immediately below the lowest div in tei:text and the four major element below tei:teiHeader.:)
                    if ($query-scope eq 'narrow')
                    then
                        for $hit in 
                            (:If both tei-text and tei-header is queried.:)
                            if (count($tei-target) eq 2)
                            then 
                                (
                                $context//tei:p[ft:query(., $queries)],
                                $context//tei:head[ft:query(., $queries)],
                                $context//tei:lg[ft:query(., $queries)],
                                $context//tei:trailer[ft:query(., $queries)],
                                $context//tei:note[ft:query(., $queries)],
                                $context//tei:list[ft:query(., $queries)],
                                $context//tei:l[not(local-name(./..) eq 'lg')][ft:query(., $queries)],
                                $context//tei:quote[ft:query(., $queries)],
                                $context//tei:table[ft:query(., $queries)],
                                $context//tei:listApp[ft:query(., $queries)],
                                $context//tei:listBibl[ft:query(., $queries)],
                                $context//tei:cit[ft:query(., $queries)],
                                $context//tei:label[ft:query(., $queries)],
                                $context//tei:encodingDesc[ft:query(., $queries)],
                                $context//tei:fileDesc[ft:query(., $queries)],
                                $context//tei:profileDesc[ft:query(., $queries)],
                                $context//tei:revisionDesc[ft:query(., $queries)]
                                )
                            else
                                if ($tei-target = 'tei-text')
                                then
                                    (
                                    $context//tei:p[ft:query(., $queries)],
                                    $context//tei:head[ft:query(., $queries)],
                                    $context//tei:lg[ft:query(., $queries)],
                                    $context//tei:trailer[ft:query(., $queries)],
                                    $context//tei:note[ft:query(., $queries)],
                                    $context//tei:list[ft:query(., $queries)],
                                    $context//tei:l[not(local-name(./..) eq 'lg')][ft:query(., $queries)],
                                    $context//tei:quote[ft:query(., $queries)],
                                    $context//tei:table[ft:query(., $queries)],
                                    $context//tei:listApp[ft:query(., $queries)],
                                    $context//tei:listBibl[ft:query(., $queries)],
                                    $context//tei:cit[ft:query(., $queries)],
                                    $context//tei:label[ft:query(., $queries)]
                                    )
                                else 
                                    if ($tei-target = 'tei-header')
                                    then 
                                        (
                                        $context//tei:encodingDesc[ft:query(., $queries)],
                                        $context//tei:fileDesc[ft:query(., $queries)],
                                        $context//tei:profileDesc[ft:query(., $queries)],
                                        $context//tei:revisionDesc[ft:query(., $queries)]
                                        )
                                    else ()    
                        order by ft:score($hit) descending
                        return $hit
                    (:If the $query-scope is broad, query the lowest div in tei:text and tei:teiHeader.:)
                    else
                        for $hit in 
                            if (count($tei-target) eq 2)
                            then
                                (
                                $context//tei:div[not(tei:div)][ft:query(., $queries)],
                                $context/descendant-or-self::tei:teiHeader[ft:query(., $queries)](:NB: Can divs occur in the header? If so, they have to be removed here5:)
                                )
                            else
                                if ($tei-target = 'tei-text')
                                then
                                    (
                                    $context//tei:div[not(tei:div)][ft:query(., $queries)]
                                    )
                                else 
                                    if ($tei-target = 'tei-header')
                                    then 
                                        $context/descendant-or-self::tei:teiHeader[ft:query(., $queries)]
                                    else ()
                        order by ft:score($hit) descending
                        return $hit
                (: The part with the ngram query mirrors that for the Lucene query, but here $queries contains a sequence of one or two non-empty strings containing the original query and the transliterated query, as indicated by the user in $query-scripts:)
                else
                    if ($query-scope eq 'narrow' and count($tei-target) eq 2)
                    then
                        for $hit in 
                            (
                            (:Only query if there is a value in the first item.:)
                            if ($queries[1]) 
                            then (
                                $context//tei:p[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:head[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:lg[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:trailer[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:note[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:list[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:l[not(local-name(./..) eq 'lg')][ngram:wildcard-contains(., $queries[1])],
                                $context//tei:quote[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:table[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:listApp[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:listBibl[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:cit[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:label[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:encodingDesc[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:fileDesc[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:profileDesc[ngram:wildcard-contains(., $queries[1])],
                                $context//tei:revisionDesc[ngram:wildcard-contains(., $queries[1])]
                                )
                            else ()
                            ,
                            (:Only query if there is a value in the second item.:)
                            if ($queries[2]) 
                            then (
                                $context//tei:p[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:head[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:lg[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:trailer[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:note[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:list[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:l[not(local-name(./..) eq 'lg')][ngram:wildcard-contains(., $queries[2])],
                                $context//tei:quote[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:table[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:listApp[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:listBibl[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:cit[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:label[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:encodingDesc[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:fileDesc[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:profileDesc[ngram:wildcard-contains(., $queries[2])],
                                $context//tei:revisionDesc[ngram:wildcard-contains(., $queries[2])]
                                ) 
                            else ()
                            )
                        order by $hit/ancestor-or-self::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1] ascending 
                        return $hit
                    else
                        if ($query-scope eq 'narrow' and $tei-target eq 'tei-text')
                        then
                            for $hit in 
                                (
                                if ($queries[1]) 
                                then (
                                    $context//tei:p[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:head[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:lg[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:trailer[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:note[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:list[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:l[not(local-name(./..) eq 'lg')][ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:quote[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:table[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:listApp[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:listBibl[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:cit[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:label[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:encodingDesc[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:fileDesc[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:profileDesc[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:revisionDesc[ngram:wildcard-contains(., $queries[1])]
                                    )
                                else ()
                                ,
                                if ($queries[2]) 
                                then (
                                    $context//tei:p[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:head[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:lg[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:trailer[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:note[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:list[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:l[not(local-name(./..) eq 'lg')][ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:quote[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:table[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:listApp[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:listBibl[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:cit[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:label[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:encodingDesc[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:fileDesc[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:profileDesc[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:revisionDesc[ngram:wildcard-contains(., $queries[2])]
                                ) 
                        else ()
                        )
                            order by $hit/ancestor-or-self::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1] ascending 
                            return $hit
                        else
                            if ($query-scope eq 'narrow' and $tei-target eq 'tei-header')
                            then
                            for $hit in 
                                (
                                if ($queries[1]) 
                                then (
                                    $context//tei:encodingDesc[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:fileDesc[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:profileDesc[ngram:wildcard-contains(., $queries[1])],
                                    $context//tei:revisionDesc[ngram:wildcard-contains(., $queries[1])]
                                ) else ()
                                ,
                                if ($queries[2]) 
                                then (
                                    $context//tei:encodingDesc[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:fileDesc[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:profileDesc[ngram:wildcard-contains(., $queries[2])],
                                    $context//tei:revisionDesc[ngram:wildcard-contains(., $queries[2])]
                                ) else ()
                                )
                            order by $hit/ancestor-or-self::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1] ascending 
                            return $hit
                            else
                                if ($query-scope eq 'broad' and count($tei-target) eq 2)
                                then
                                    for $hit in
                                        (
                                        if ($queries[1])
                                        then
                                            (
                                            $context//tei:div[not(tei:div)][ngram:wildcard-contains(., $queries[1])],
                                            $context//tei:teiHeader[ngram:wildcard-contains(., $queries[1])]
                                            ) 
                                        else ()
                                        ,
                                        if ($queries[2]) 
                                        then (
                                            $context//tei:div[not(tei:div)][ngram:wildcard-contains(., $queries[2])],
                                            $context//tei:teiHeader[ngram:wildcard-contains(., $queries[2])]
                                            ) 
                                        else ()
                                        )
                                    order by $hit/ancestor-or-self::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1] ascending
                                    return $hit
                                else
                                    if ($query-scope eq 'broad' and $tei-target eq 'tei-text')
                                    then
                                        for $hit in (
                                            if ($queries[1])
                                            then
                                                $context//tei:div[not(tei:div)][ngram:wildcard-contains(., $queries[1])]
                                            else ()
                                            ,
                                            if ($queries[2]) 
                                            then
                                                $context//tei:div[not(tei:div)][ngram:wildcard-contains(., $queries[2])]
                                            else ()
                                        )
                                        order by $hit/ancestor-or-self::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1] ascending
                                        return $hit
                                    else 
                                        if ($query-scope eq 'broad' and $tei-target eq 'tei-header')
                                        then 
                                        for $hit in (
                                            if ($queries[1]) then
                                                $context//tei:teiHeader[ngram:wildcard-contains(., $queries[1])]
                                            else ()
                                            ,
                                            if ($queries[2]) then
                                                $context//tei:teiHeader[ngram:wildcard-contains(., $queries[2])]
                                            else
                                                ()
                                            )
                                            order by $hit/ancestor-or-self::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1] ascending
                                            return $hit
                                        else ()
            let $hits := 
                if ($bool eq 'or')
                then session:get-attribute("apps.sarit.hits") union $hits
                else 
                    if ($bool eq 'and')
                    then session:get-attribute("apps.sarit.hits") intersect $hits
                    else
                        if ($bool eq 'not')
                        then session:get-attribute("apps.sarit.hits") except $hits
                        else $hits
            (:gather up previous searches for match highlighting.:)
            (:NB: lucene-queries may have slashes added, so they may be different from ngram-queries:)
            let $ngram-query :=
                if ($index eq 'ngram')
                then
                    if ($bool eq 'new')
                    then $queries
                    else
                        if ($bool = ('or', 'and'))
                        then ($queries, session:get-attribute("apps.sarit.ngram-query"))
                        else
                            if ($bool eq 'not')
                            then session:get-attribute("apps.sarit.ngram-query")
                            else ''
                else ''
            let $lucene-query :=
                if ($index eq 'lucene')
                then
                    if ($bool eq 'new')
                    then $queries
                    else
                        if ($bool = ('or', 'and'))
                        then ($queries, session:get-attribute("apps.sarit.lucene-query"))
                        else
                            if ($bool eq 'not')
                            then session:get-attribute("apps.sarit.lucene-query")
                            else ''
                else ''
            let $store := (
                session:set-attribute("apps.sarit.hits", $hits),
                session:set-attribute("apps.sarit.index", $index),
                session:set-attribute("apps.sarit.ngram-query", $ngram-query),
                session:set-attribute("apps.sarit.lucene-query", $lucene-query),
                session:set-attribute("apps.sarit.scope", $query-scope),
                session:set-attribute("apps.sarit.bool", $bool)
                )
            return
                (: The hits are not returned directly, but processed by the nested templates :)
                map {
                    "hits" := $hits,
                    "ngram-query" := $ngram-query,
                    "lucene-query" := $lucene-query
                }
};

(:~
    app:expand-query transliterates the query string from Devanagari to IAST transcription and/or from IAST transcription to Devanagari, 
    if the user has indicated that this is wanted in $query-scripts. 
:)
declare %private function app:expand-query($query as xs:string*, $query-scripts as xs:string?) as xs:string* {
    if ($query)
    then (
        sarit:create("devnag2roman", $app:devnag2roman/string()),
        sarit:create("roman2devnag", $app:roman2devnag-search/string()),
        sarit:create("expand", $app:expand/string()),
        (:if there is input exclusively in IAST romanization:)
        if (not(matches($query, $app:iast-char-repertoire-negation))) 
        then
            (:if the user wants to search in Devanagri, then transliterate and discard the original query:)
            if ($query-scripts eq "sa-Deva") 
            then
                sarit:transliterate("expand",translate(sarit:transliterate("roman2devnag", $query), "&#8204;", ""))
            else 
                (:if the user wants to search in both IAST and Devanagri, then transliterate the original query and keep it:)
                if ($query-scripts eq "all")
                then
                    ($query, sarit:transliterate("expand",translate(sarit:transliterate("roman2devnag", $query), "&#8204;", "")))
                else 
                    (:if the user wants to search in romanization, then do not transliterate but keep original query:)
                    if ($query-scripts eq "sa-Latn") 
                    then 
                        $query
                    (:this exhausts all options for IAST input strings:)
                    else ''
        else
            (:if there is input exclusively in Devanagari:)
            if (empty(string-to-codepoints($query)[not(. = (9-13, 32, 133, 160, 2304 to 2431, 43232 to 43259, 7376 to 7412))])) 
            then
                (:if the user wants to search in IAST, then transliterate the original query but delete it:)
                if ($query-scripts eq "sa-Latn") 
                then
                    sarit:transliterate("devnag2roman", $query)
                else
                    (:if the user wants to search in both Devanagri and IAST, then transliterate the original query and keep it:)
                    if ($query-scripts eq "all")
                    then
                        (sarit:transliterate("expand",$query), sarit:transliterate("devnag2roman", $query))
                    else 
                        (:if the user wants to search in Devanagri, then do not transliterate original query but keep it:)
                        if ($query-scripts eq "sa-Deva")
                        then
                            sarit:transliterate("expand", $query)
                        else ''
            (:there should only be two options: IAST and Devanagari input. If the query is not pure IAST and is not pure Devanagari, then do not (try to) transliterate the original query but keep it as it is.:)
            else
                $query
    ) 
    else ()
};

(:~
 : Create a bootstrap pagination element to navigate through the hits.
 :)
(:template function in search.html:)
declare
    %templates:wrap
    %templates:default('start', 1)
    %templates:default("per-page", 10)
    %templates:default("min-hits", 0)
    %templates:default("max-pages", 10)
function app:paginate($node as node(), $model as map(*), $start as xs:int, $per-page as xs:int, $min-hits as xs:int,
    $max-pages as xs:int) {
    if ($min-hits < 0 or count($model("hits")) >= $min-hits) then
        let $count := xs:integer(ceiling(count($model("hits"))) div $per-page) + 1
        let $middle := ($max-pages + 1) idiv 2
        return (
            if ($start = 1) then (
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-fast-backward"/></a>
                </li>,
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-backward"/></a>
                </li>
            ) else (
                <li>
                    <a href="?start=1"><i class="glyphicon glyphicon-fast-backward"/></a>
                </li>,
                <li>
                    <a href="?start={max( ($start - $per-page, 1 ) ) }"><i class="glyphicon glyphicon-backward"/></a>
                </li>
            ),
            let $startPage := xs:integer(ceiling($start div $per-page))
            let $lowerBound := max(($startPage - ($max-pages idiv 2), 1))
            let $upperBound := min(($lowerBound + $max-pages - 1, $count))
            let $lowerBound := max(($upperBound - $max-pages + 1, 1))
            for $i in $lowerBound to $upperBound
            return
                if ($i = ceiling($start div $per-page)) then
                    <li class="active"><a href="?start={max( (($i - 1) * $per-page + 1, 1) )}">{$i}</a></li>
                else
                    <li><a href="?start={max( (($i - 1) * $per-page + 1, 1)) }">{$i}</a></li>,
            if ($start + $per-page < count($model("hits"))) then (
                <li>
                    <a href="?start={$start + $per-page}"><i class="glyphicon glyphicon-forward"/></a>
                </li>,
                <li>
                    <a href="?start={max( (($count - 1) * $per-page + 1, 1))}"><i class="glyphicon glyphicon-fast-forward"/></a>
                </li>
            ) else (
                <li class="disabled">
                    <a><i class="glyphicon glyphicon-forward"/></a>
                </li>,
                <li>
                    <a><i class="glyphicon glyphicon-fast-forward"/></a>
                </li>
            )
        ) else
            ()
};

(:~
    Create a span with the number of items in the current search result.
:)
(:template function in search.html:)
declare function app:hit-count($node as node()*, $model as map(*)) {
    <span xmlns="http://www.w3.org/1999/xhtml" id="hit-count">{ count($model("hits")) }</span>
};

(:~
    Output the actual search result as a div, using the kwic module to summarize full text matches.
:)
(:template function in search.html:)
declare 
    %templates:wrap
    %templates:default("start", 1)
    %templates:default("per-page", 10)
function app:show-hits($node as node()*, $model as map(*), $start as xs:integer, $per-page as xs:integer) {
    let $index := session:get-attribute("apps.sarit.index")
    for $hit at $p in subsequence($model("hits"), $start, $per-page)
    (: we try if the hit has a div ancestor (or is itself a div) and take the first one (or itself), 
    in order to be able to output the link to the hit context ($ancestor-id) and a header ($ancestor-head). :)
    let $ancestor := $hit/ancestor-or-self::tei:div[1]
    (: if it does not have a div ancestor, we try something else. :)
    let $ancestor := if ($ancestor) then $ancestor else ($hit/ancestor-or-self::tei:trailer, $hit/ancestor-or-self::tei:front, $hit/ancestor-or-self::tei:back, $hit/ancestor-or-self::tei:teiHeader)[1]
    (: NB: there are lots of theoretical possibilities for non-div ancestors: we use only the values that occur in the corpus. :)
    let $ancestor-id := ($ancestor/@xml:id/string(), util:document-name($ancestor) || "_" || util:node-id($ancestor))[1]
    (: NB: I do not understand why we need to add to the context of $ancestor, if the only thing we want from it is the link id and the header. :)
    let $ancestor := app:get-previous($ancestor) 
    (: NB: no-div ancestors will not have heads. :)
    let $ancestor-head := string-join($ancestor/tei:head/text())
    let $work := $hit/ancestor::tei:TEI
    let $work-title := app:work-title($work)
    (: the work always has an xml:id. :)
    let $work-id := $work/@xml:id/string()
    (: pad the hit with its surrounding siblings. :)
    (: NB: we could have fed $ancestor instead of $hit-padded to kwic:summarize, 
    but this too much would have to be discarded, and the result would probably have been the same. :)
(:    let $hit-padded := <hit>{($hit/preceding-sibling::*[1], $hit, $hit/following-sibling::*[1])}</hit>:)
    let $loc := 
        <tr class="reference">
            <td colspan="3">
                <span class="number">{$start + $p - 1}</span>
                <a href="{$work-id}">{$work-title}</a>{if ($ancestor-head) then ', ' else ''}<a href="{$ancestor-id}.html">{$ancestor-head}</a>
            </td>
        </tr>
    let $matchId := util:node-id($hit)
    let $config := <config width="70" table="yes" link="{$ancestor-id}.html?action=search#{$matchId}"/>
    let $kwic := kwic:summarize($ancestor, $config)
    let $kwic :=
        (:only clean up kwic if ngram search is employed on Devanagari text:)
        if ($index eq "lucene" or $hit/ancestor-or-self::*[@xml:lang][1]/@xml:lang eq "sa-Latn")
        then $kwic
        else app:clean-up-kwic($kwic)
    return
        ($loc, $kwic)        
};

(:~
    Function which 1) moves any combining marks orphaned in the beginning of "following" to the end of "hit", 2) moves any combining marks orphaned in the beginning of "hit" to the end of "previous", 3) removes any combining marks orphaned in the beginning of "previous"
:)
declare %private function app:clean-up-kwic($kwic as element(tr) +)
as element(tr)
{
    let $kwic := $kwic[1] (: NB: Why is position necessary here? :)
    (: we get the four strings we need; all except $href need manipulation :)
    let $left-context := $kwic//td[1]/string()
    let $hit := $kwic//td[2]/string()
    let $href := $kwic//td[2]/a/@href/string()
    let $right-context := $kwic//td[3]/string()
    (: the right context may have 1) initial combining marks and 2) a body following any such marks, and it has 3) trailing dots :)
    (: we isolate any initial combining marks from the right context :)
    let $right-context-initial-combining-chars :=
        replace($right-context, "(\p{M}*)(.*)", "$1", "s")
    (: we get the body plus dots of the right context:)
    (: TODO: try using functx:use substring-after-if-contains() here :)
    let $right-context := replace($right-context, "(\p{M}*)(.*)", "$2", "s")
    (: we remove the dots from the right context :)
    let $right-context := functx:substring-before-if-contains($right-context, ' ...')
    (: we remove any combining marks at the beginning of the right context:)
    (: NB: why can't "substring-after($right-context, $right-context-initial-combining-chars)" or 
    functx:use substring-after-if-contains()? be used? :)
    let $right-context :=
        replace($right-context, concat("(^", $right-context-initial-combining-chars, ")", "(.*)"), "$2", "s")
    (: we append dots to the right context if there is anything to append them to :)
    let $right-context :=
        if ($right-context) then
            concat($right-context, ' …')
        else
            ''
    (: we append any combining marks from the beginning of the right context to the hit :)
    let $hit := concat($hit, $right-context-initial-combining-chars)
    (: we isolate any initial combining marks in the hit :)
    let $hit-initial-combining-chars :=
        replace($hit, "(\p{M}*)(.*)", "$1", "s")
    (: we remove the dots from the beginning of the left context :)
    let $left-context :=
        functx:substring-after-if-contains($left-context, "... ")
    (: we remove any initial combining marks from the left context :)
    let $left-context :=
        replace($left-context, "^(\p{M}*)(.*)", "$2", "s")
    (: NB: try replace($left-context, "^(\P{M}\p{M}*)(.*)$", "$2", "s"):)
    (:if the hit contains an initial combining mark, we plan to move the last non-combining character of the left context 
    (along with any non-combining character that may follow it) to the beginning of the hit:)
    (: we first isolate any base character plus combining mark from the end of the context :)
    let $left-context-final-base-char :=
        if ($hit-initial-combining-chars) then 
            replace($left-context, "^(.*)(\P{M}\p{M}*)$", "$2", "s")
        else ''
    (: we add it to the beginning of the hit :)
    let $hit := concat($left-context-final-base-char, $hit)
    (: we remove what we have added to the hit from the left context :)
    let $left-context := functx:substring-before-last($left-context, $left-context-final-base-char)
    (: we add dots to the left context if there is anything elided :)
    let $left-context :=
        if ($left-context) then
            concat('… ', $left-context)
        else
            ''
    return
        <tr>
            <td class="previous">{ $left-context }</td>
            <td class="hi"><a href="{ $href }">{ $hit }</a></td>
            <td class="following">{ $right-context }</td>
        </tr>
};

(: This functions provides crude way to avoid the most common errors with paired expressions and apostrophes. :)
(: TODO: check order of pairs:)
declare %private function app:sanitize-lucene-query($query-string as xs:string) as xs:string {
    let $query-string := replace($query-string, "'", "''") (:escape apostrophes:)
    (:TODO: notify user if query has been modified.:)
    (:Remove colons – Lucene fields are not supported.:)
    let $query-string := translate($query-string, ":", " ")
    let $query-string := 
       if (functx:number-of-matches($query-string, '"') mod 2 eq 0) 
       then $query-string
       else replace($query-string, '"', ' ') (:if there is an uneven number of quotation marks, delete all quotation marks.:)
    let $query-string := 
       if (functx:number-of-matches($query-string, '/') mod 2 eq 0) 
       then $query-string
       else replace($query-string, '/', ' ') (:if there is an uneven number of slashes, delete all quotation marks.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '\(') + functx:number-of-matches($query-string, '\)')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '()', ' ') (:if there is an uneven number of parentheses, delete all parentheses.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '\[') + functx:number-of-matches($query-string, '\]')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '[]', ' ') (:if there is an uneven number of brackets, delete all brackets.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '{') + functx:number-of-matches($query-string, '}')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '{}', ' ') (:if there is an uneven number of braces, delete all braces.:)
    let $query-string := 
       if ((functx:number-of-matches($query-string, '<') + functx:number-of-matches($query-string, '>')) mod 2 eq 0) 
       then $query-string
       else translate($query-string, '<>', ' ') (:if there is an uneven number of angle brackets, delete all angle brackets.:)
    return $query-string
};