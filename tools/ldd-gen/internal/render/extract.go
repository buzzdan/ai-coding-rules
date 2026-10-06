package render

import (
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// sectionBody returns the text under "## <heading>" up to the next "## "
// heading or the end of the file, with surrounding blank lines removed.
func sectionBody(doc, heading string) (string, bool) {
	lines := strings.Split(doc, "\n")
	start := -1
	for i, line := range lines {
		if start < 0 {
			if strings.TrimSpace(line) == "## "+heading {
				start = i + 1
			}
			continue
		}
		if strings.HasPrefix(line, "## ") {
			return strings.TrimSpace(strings.Join(lines[start:i], "\n")), true
		}
	}
	if start < 0 {
		return "", false
	}
	return strings.TrimSpace(strings.Join(lines[start:], "\n")), true
}

// boldLeads returns, for every line that starts with prefix followed by a bold
// span, the text inside that span: the name a bullet leads with.
func boldLeads(text, prefix string) []string {
	var leads []string
	for _, line := range strings.Split(text, "\n") {
		rest, ok := strings.CutPrefix(line, prefix+"**")
		if !ok {
			continue
		}
		if lead, _, closed := strings.Cut(rest, "**"); closed {
			leads = append(leads, lead)
		}
	}
	return leads
}

var numberedBold = regexp.MustCompile(`^(\d+)\. \*\*`)

// numberedHeadlines maps each "N. **headline**" item to its headline. A
// headline may wrap onto following lines; it ends at the closing bold marker.
func numberedHeadlines(text string) map[int]string {
	lines := strings.Split(text, "\n")
	out := map[int]string{}
	for i, line := range lines {
		m := numberedBold.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		n, _ := strconv.Atoi(m[1]) // the pattern admits digits only
		rest := strings.TrimPrefix(line, m[0])
		if headline, ok := closeBold(rest, lines[i+1:]); ok {
			out[n] = headline
		}
	}
	return out
}

// closeBold joins first and as many following lines as needed to reach the
// closing "**", returning the text before it.
func closeBold(first string, following []string) (string, bool) {
	text := first
	for i := 0; ; i++ {
		if headline, _, closed := strings.Cut(text, "**"); closed {
			return strings.Join(strings.Fields(headline), " "), true
		}
		if i == len(following) || strings.TrimSpace(following[i]) == "" {
			return "", false
		}
		text += " " + strings.TrimSpace(following[i])
	}
}

// joinValues joins a numbered map's values in number order with " · ".
func joinValues(m map[int]string) string {
	nums := make([]int, 0, len(m))
	for n := range m {
		nums = append(nums, n)
	}
	sort.Ints(nums)
	parts := make([]string, 0, len(nums))
	for _, n := range nums {
		parts = append(parts, m[n])
	}
	return strings.Join(parts, " · ")
}

// maximAsk returns the "**Ask:**" paragraph under the "### <title>" heading,
// joined into one line without the label.
func maximAsk(doc, title string) (string, bool) {
	lines := strings.Split(doc, "\n")
	inMaxim := false
	for i, line := range lines {
		if strings.HasPrefix(line, "### ") {
			inMaxim = strings.TrimSpace(strings.TrimPrefix(line, "### ")) == title
			continue
		}
		if inMaxim && strings.HasPrefix(line, "**Ask:**") {
			return paragraph(lines[i:], "**Ask:**"), true
		}
	}
	return "", false
}

// paragraph joins lines up to the first blank one, dropping a leading label.
func paragraph(lines []string, label string) string {
	var words []string
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			break
		}
		words = append(words, strings.Fields(strings.TrimPrefix(line, label))...)
	}
	return strings.Join(words, " ")
}
