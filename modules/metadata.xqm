xquery version "3.0";

module namespace metadata = "http://exist-db.org/ns/sarit/metadata/";

import module namespace config = "http://exist-db.org/apps/appblueprint/config" at "config.xqm";
import module namespace app = "http://exist-db.org/apps/appblueprint/templates" at "app.xql";
import module "http://expath.org/ns/pdf";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $metadata:metadata := doc($config:remote-root || "/metadata.xml")/*;

declare function metadata:count-pdf-pages() {
    let $pdf-files-collection := $config:remote-root || "/download/pdf/"
    let $pdf-work-pages :=
        for $pdf-file-name in xmldb:get-child-resources($pdf-files-collection)
        let $pdf-file-path := $pdf-files-collection || $pdf-file-name
        
        return map:get(pdf:get-metadata(util:binary-doc($pdf-file-path)), "number-of-pages")
        
    let $pdf-work-pages-total := sum($pdf-work-pages)
    
    let $store-pdf-work-pages-total := update value $metadata:metadata/metadata:number-of-pdf-pages with $pdf-work-pages-total

    
    return $pdf-work-pages-total
};

declare function metadata:get-relevant-xml-works() {
    let $work-titles :=
        for $work in collection($config:remote-data-root)/tei:TEI
        return
            app:work-title($work)
    let $works :=
        for $work in collection($config:remote-data-root)/tei:TEI
        let $work-title := app:work-title($work)
        let $work-script := $work//tei:text/@xml:lang
        let $work-script := if ($work-script eq 'sa-Latn') then 'IAST' else 'Devanagari'
        return
            if (count(index-of($work-titles, $work-title)) > 1)
            then
                if ($work-script = 'Devanagari')
                then $work
                else ()
            else $work

    
    return $works
};

declare function metadata:count-relevant-xml-works() {
    let $number-of-relevant-xml-works := count(metadata:get-relevant-xml-works())
    let $store-number-of-relevant-xml-works := update value $metadata:metadata/metadata:number-of-xml-works with $number-of-relevant-xml-works
    
    return $number-of-relevant-xml-works
};
