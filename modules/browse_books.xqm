xquery version "1.0";

module namespace browse-books="http://exist-db.org/xquery/apps/matumi/browse-books";

declare namespace anno="http://exist-db.org/xquery/annotate";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare default element namespace "http://www.tei-c.org/ns/1.0";
declare copy-namespaces no-preserve, no-inherit;
declare boundary-space strip;

import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";

declare function browse-books:data-all( $context-nodes as node()*, $URIs as node()*, $level-pos as xs:int ){
   if( $level-pos = 1 ) then 
        collection(concat($config:app-root, '/data'))//tei:TEI        
   else $context-nodes/ancestor-or-self::tei:TEI
};

declare function browse-books:data-filtered( $data as node()*, $URIs as node()* ){       
    if(  exists($URIs) ) then (
        for $d in $data return
        if( document-uri( root($d)) =  $URIs/uri ) then 
            $d 
        else ()
    )else   
        $data    
};

declare function browse-books:title-extract( $title as element(tei:titleStmt)?, $URIs as node()* ){     
     if( exists($title)) then
         let $root := root($title)
         let $uri := document-uri( $root ) 
         return element title {
            if( $uri = $URIs/uri ) then attribute {'selected'}{'true'} else (),
            attribute {'language'}{ string($root/text/@xml:lang)  },     
            attribute {'value'} { $uri },            
            attribute {'uri'} { $uri },
            
            if( exists($title/title[@type='main']) ) then
                 $title/title[@type="main"]   
            else if( string($title) = 'Title' or empty($title/title) or fn:string-join($title/title,'') = '' ) then 
                 concat('[',  util:document-name($title), ']') 
            else $title/title
         }   
     else <title>Missing Title</title>
};


declare function browse-books:titles-list( $nodes as element()*,  $level as node()?, $URIs as node()*, $Categories as element(category)* ){
    element titles {
         attribute {'name'}{ 'uri' },
         attribute {'count'}{ count($nodes)},
         attribute {'title'}{ $level/@title },
         element {'group'}{
             for $title in $nodes//tei:fileDesc/tei:titleStmt
             let $title2 := browse-books:title-extract($title, $URIs )
             order by string($title2)
             return $title2
         }
    }    
};



(:

declare function browse-books:data( $context-nodes as node()*, $URIs as node()*, $level-pos as xs:int ){
   if( $level-pos = 1 ) then (
        (:   no context nodes expected   :) 
        if( exists($URIs) ) then (
           for $uri in  $URIs/uri return 
               if( doc-available($uri)) then
                      doc($uri)//tei:TEI    
               else <error uri="{$uri}">missing book:{ $uri }</error>            
        
        )else ( 
           (:   all available data   :)
           collection(concat($config:app-root, '/data'))//tei:TEI
        )
    )else (
       (:   get the root TEI elements    :)
       let $data := () | $context-nodes/ancestor-or-self::tei:TEI 
       return if(  exists($URIs) ) then (
          for $d in $data return
          if( document-uri( root($d)) =  $URIs/uri ) then $d else ()
       )else 
          $data
    )
};


declare function browse-books:list( $books as element()*){
   for $book in $books
     let $titleStmt := $books//teiHeader/fileDesc/titleStmt
     let $root := $book/ancestor-or-self::tei:TEI
     
   return 
   element book {       
       attribute {'language'}{ string($root/text/@xml:lang)  },       
       attribute uri { document-uri( root($book)) },   
       attribute file { util:document-name($book) }
   }
};

local:roots( $nodes )//teiHeader/fileDesc

declare function browse-books:titles-data( $nodes as node()*){
    local:roots( $nodes )/text/body/head    
};
declare function browse-books:books( $nodes as node()*){
    local:roots( $nodes )//teiHeader/fileDesc
};

declare function browse-books:books-entries-list( $fileDesc as element()*){
   for $book in $fileDesc/titleStmt 
     let $root := $book/ancestor-or-self::tei:TEI,
         $entries := $root/text/body/div[@type="entry"]
     
   return 
   element book {
       $book/*,
       element {'language'}{ string($root/text/@xml:lang)  },       
       element uri { document-uri( root($book)) },   
  (:     element uri { concat(util:collection-name($book), '/',  util:document-name($book))}, :)
       element file { util:document-name($book) },
       element node-id { util:node-id($book) },
       element {'entries'}{ 
         attribute {'count'}{ count($entries) },         
         for $e in $entries return 
            element entry{
                attribute {'node-id'}{ util:node-id($e) },
                attribute {'articles'}{ count( $e/div[ @type="article" ]) },
                $e/head
            }
      }
   }
};
:)
