# Recap email template

Sent by Flipside when the phone closes (hinge status `closed`) after the last slide.
Rules: one subject line, five lines max in the body, plain English, no em dashes.
Placeholders are in double braces. Drop line 4 when no questions were captured.

## Subject

Recap: {{deck_title}} with {{presenter_name}}

## Body

Hi {{recipient_first_name}},
{{presenter_name}} just presented "{{deck_title}}" from Flipside. It ran {{slide_count}} slides in {{duration_minutes}} minutes.
The short version: {{one_line_takeaway}}
Questions raised: {{questions_or_none}}
Slides and notes are here: {{recap_link}}

## Placeholders

| Placeholder | Filled from |
|---|---|
| deck_title | title of slide 1 |
| presenter_name | the signed-in presenter |
| recipient_first_name | the recipient's first name, or "there" if unknown |
| slide_count | number of slides shown, including any live-generated ones |
| duration_minutes | elapsed time from first slide to fold, rounded up |
| one_line_takeaway | body text of the last slide, trimmed to one sentence |
| questions_or_none | captured questions joined with semicolons, or "none" |
| recap_link | link to the deck with notes |

## Example (self-pitch deck)

Subject: Recap: Flipside with Kartik

Hi there,
Kartik just presented "Flipside" from Flipside. It ran 9 slides in 5 minutes.
The short version: When the phone closes, the talk is over and a five-line recap is already in your inbox.
Questions raised: none
Slides and notes are here: https://example.invalid/recap/flipside
