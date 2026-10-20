# Usage: awk -f flatten.awk talk/talk.md > build/talk-flat.md
#
# 1. Inlines every `<!-- include: path -->` (paths relative to the talk file).
#    presenterm 0.16.1's speaker-notes listener ignores includes.
# 2. Moves each slide's speaker notes right under its `===` title, ahead of any
#    `<!-- pause -->`, so the notes window shows them all as soon as the slide opens.
#    The presenter ignores note comments, so the slides themselves don't change.

BEGIN { n = 0 }

FNR == 1 { dir = FILENAME; sub(/[^\/]*$/, "", dir) }

{
    if (match($0, /^<!-- include: .* -->$/)) {
        f = dir substr($0, 15, length($0) - 18)
        while ((getline l < f) > 0) take(l)
        close(f)
    } else {
        take($0)
    }
}

END { flush() }

function take(line) {
    if (line ~ /^```/) fenced = !fenced
    slide[++n] = line
    if (!fenced && line == "<!-- end_slide -->") flush()
}

function flush(    i, j, nb, nn, body, notes, in_note, title_at, fence) {
    nb = nn = 0; in_note = 0; fence = 0
    for (i = 1; i <= n; i++) {
        if (slide[i] ~ /^```/) fence = !fence
        if (!fence && !in_note && slide[i] == "<!--" && i < n && slide[i + 1] ~ /^speaker_note:/) in_note = 1
        if (in_note) {
            notes[++nn] = slide[i]
            if (slide[i] == "-->") { in_note = 0; notes[++nn] = "" }
            continue
        }
        if (!fence && slide[i] ~ /^<!-- speaker_note:.*-->$/) { notes[++nn] = slide[i]; notes[++nn] = ""; continue }
        body[++nb] = slide[i]
    }
    title_at = 0
    fence = 0
    for (i = 1; i <= nb && !title_at; i++) {
        if (body[i] ~ /^```/) fence = !fence
        if (!fence && body[i] ~ /^===+$/) title_at = i
    }
    for (i = 1; i <= nb; i++) {
        if (i == 1 && title_at == 0) for (j = 1; j <= nn; j++) print notes[j]
        print body[i]
        if (i == title_at && nn) { print ""; for (j = 1; j <= nn; j++) print notes[j] }
    }
    n = 0
}
