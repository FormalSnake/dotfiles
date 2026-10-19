# Copy

Every shipped string (headings, buttons, meta descriptions, alt text, legal
page intros, docs) follows the Microsoft Writing Style Guide.

## Rules

| Rule | Do | Don't |
| --- | --- | --- |
| Address the reader | "You send the invoice, we file the record." | "Users can send invoices." |
| Contractions | "You don't need a gestor for this." | "You do not need..." |
| Active voice | "We send each record to the tax agency." | "Each record is sent..." |
| Sentence case | "Start your free trial" | "Start Your Free Trial" |
| Short | One idea per sentence, headings under ~10 words | Stacked clauses |
| Concrete | "Ready in two minutes", "€9 a month" | "Fast and affordable" |
| Say it once | Body adds a fact the heading doesn't have | A subtitle that restates the heading |
| Buttons | Verb first, says what happens: "Create account", "See pricing" | "Submit", "Learn more", "Click here" |
| Links | The link text alone makes sense | "here", "this page" |

## Banned

Words and phrases: comprehensive, robust, seamless(ly), powerful, leverage,
delve, elevate, streamline, significantly, cutting-edge, state-of-the-art,
revolutionary, game-changer, unlock, empower, effortless(ly), world-class,
best-in-class, next-generation, innovative, supercharge, simply, just (as a
minimiser), easy/easily (show it instead), "it's worth noting", "in today's
fast-paced world", "say goodbye to".

Constructions:

* No em dashes (U+2014) and no en dashes with a space on each side (U+2013
  used as a dash) anywhere: copy, alt text, meta, JSON-LD, docs, code
  comments. Use a comma, a colon, parentheses or two sentences. An unspaced en
  dash in a range (9 to 17h written with U+2013) is fine.
* No rule of three for rhythm ("fast, simple and secure"). Say the one thing
  that is true.
* No negative parallelism ("Not just X, it's Y").
* No eyebrows/kickers, no uppercase labels, no exclamation marks in headings.
* No invented testimonials, logos, user counts or ratings.

Check before shipping:

```sh
rg -n '\x{2014}|\s\x{2013}\s' src
rg -n -i '\b(seamless|robust|powerful|leverage|effortless|cutting-edge|unlock|empower|revolutionary)' src
```

## Spanish

Same principles, adapted:

* Tú, never usted: "Envías la factura y nosotros presentamos el registro."
* Sentence case (Spanish already does this; keep it in buttons and headings).
* Active voice, short sentences, concrete numbers.
* Banned equivalents: potente, robusto, integral, sin fisuras, revolucionario,
  innovador, de vanguardia, líder del sector, solución integral, "olvídate de",
  "sencillamente".
* Spanish punctuation: opening ¿ and ¡, `€` after the amount with a space
  (`9 €`), decimal comma (`1.234,56 €`). Use `Intl.NumberFormat` for money, not
  hand-built strings.
* Endonyms in the language switcher: "Español", "English".
* The Spanish page is written, not translated: reread it as a native reader and
  fix calques ("aplicar" for "apply for", "soportar" for "support").

## Meta and SEO strings

* `<title>`: keyword first, brand last: "Facturación VERI*FACTU para autónomos · CanaryFactura".
* Description: one or two plain sentences, 140 to 160 characters, no banned words.
* Same rules for Open Graph alt text and `llms.txt`.
