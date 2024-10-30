view! {
    <vxmlSample attr1="mom" attr2="dad">
        r#"this is a text childwith two lines"#
        <html>
            r#"this is a text childwith two lines"#<header charset="utf-8"></header>
            <body>
                r#"this is a text childwith two lines"#<header charset="utf-8"></header>
                <div>
                    r#"this is a text childwith two lines"#<header charset="utf-8"></header>
                    r#"some textmore textfurther text"#r#"consecutive textnode"#
                </div>
            </body>
            <goda>
                r#"this is a text childwith two lines"#<header charset="utf-8"></header>
                <body>
                    r#"this is a text childwith two lines"#<header charset="utf-8"></header>
                    <div>
                        r#"this is a text childwith two lines"#<header charset="utf-8"></header>
                        r#"some textmore textfurther text"#r#"consecutive textnode"#
                    </div>
                </body><child1 attr5="value23"></child1><child2></child2>
                r#"hello I am child3, but the first text child"#<child4></child4>
            </goda>
        </html>
    </vxmlSample>
    <yello></yello>
}