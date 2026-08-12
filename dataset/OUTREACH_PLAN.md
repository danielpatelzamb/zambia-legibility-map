# How to actually get meetings. Zambian minerals sector

Built from `outreach_targets.csv` (224 reachable organisations), `sector_directory.csv`
(institutional conveners), `individual_holders.csv` (902 individual holders, located by district)
and `asm_outreach_channels.json`.

**The core insight:** cold-emailing 1,300 companies is the worst available strategy. ~94% of the
deep register has no published channel, and the ones that do are mostly gatekept. The efficient
paths are (a) conveners who assemble many companies at once, and (b) the 224 you can already
reach directly, prioritised by materiality.

---

## 1. Conferences, the highest-yield play by far

One trip puts you in a room with more operators than a year of cold outreach.

| Event | Why it works |
|---|---|
| **ZIMEC** (Zambia International Mining & Energy Conference) | Zambia-specific. Operators, MMMD officials and suppliers in one venue. Exhibitor lists are published, so you can pre-book meetings by name. |
| **Mining Indaba** (Cape Town, February) | Every Zambian major plus juniors and their London/Perth/Toronto parents. Investor-relations staff attend specifically to take meetings. |
| **Zambia International Trade Fair** (Ndola, ~July) | Copperbelt SMEs and quarry/lime operators who never attend international events. |
| **Copperbelt Mining Trade Expo / ZIMEC regional** | The mid-tier and service companies. |

**Method:** get the exhibitor list in advance, cross-match against `outreach_targets.csv`, and
request meetings by name and stand number. Student/academic rates usually exist: ask the
organiser directly, and say it is university research.

## 2. Institutional conveners: borrow their credibility

These bodies can introduce you to members in one email. 30 of them in `sector_directory.csv`
already have a phone or email.

- **Zambia Chamber of Mines**, the members are the majors and mid-tier. A chamber-endorsed
  research request reaches all of them at once. Start here.
- **ZEITI Secretariat**: runs the multi-stakeholder group (government, companies, civil society).
  Their working groups are literally standing meetings with the companies in your dataset.
- **MMMD** (Ministry of Mines): for policy-side interviews and for introductions to licence
  holders; the provincial and district offices hold the licence files.
- **ZAM** (Zambia Association of Manufacturers): for the value-addition/fabrication segment.
- **UNZA School of Mines / Copperbelt University**, they run Zambian ASM and mining fieldwork
  continuously. A local co-investigator solves access, language and trust in one move, and is
  what an IRB will expect anyway.
- **ASM associations and cooperatives** (see `asm_outreach_channels.json`), the only legitimate
  route to the 902 individual holders.

## 3. The 224 you can reach directly: work them in tiers

`outreach_targets.csv` is sorted for exactly this. Channel mix: 130 email, 160 phone,
58 LinkedIn, 25 with a company-published named contact.

- **Tier 0: anchors (21).** Majors and institutions with full contact sets, 12 of them with
  per-facility contacts (mine site vs Lusaka office). Their **investor-relations or media desks
  answer research requests**, that is what those inboxes are for. For foreign-listed parents
  (FQM, Barrick, Vedanta, Jubilee, Shuka, GoviEx, Moxico, Galileo, Patriot, Arc) the IR contact
  is the single most responsive door in the whole dataset.
- **Tier 1: majors (47).** ≥50,000 ha or ≥3 mining licences. Highest research value per meeting.
- **Tier 2: substantive (136).** ≥5,000 ha or holding a mining licence. The mid-tier that
  nobody interviews: likely your most original material.
- **Tier 3: small (20).** Reachable but marginal; deprioritise.

**Sequencing that works:** LinkedIn connection request with a one-line research note → then the
company email citing the LinkedIn contact → then phone. Warm-ish beats cold, and LinkedIn gets
you a named human instead of `info@`.

## 4. Use the data as the hook

You are not asking for a favour, you have something they want to see. Openers that earn replies:

- **"You appear in the 18 June 2025 default notice"**. 2,332 holders do. Companies want to
  explain or correct that, and many will take a call to do it.
- **"Our records show X ha across Y licences in [district]"**: showing you already know their
  operation shifts the conversation from cold call to fact-check.
- **"Your beneficial-ownership declaration is outstanding at PACRA"**. 729 companies. Handle
  with care, but it is a legitimate and highly motivating reason to engage.
- **Offer them the data.** Send the entity's own row. Sector participants rarely see themselves
  in a consolidated dataset and will often meet just to see it.

## 5. Draft outreach note (adapt, don't send verbatim)

> Subject: Harvard research on Zambia's minerals sector: request for a short interview
>
> Dear [Name / Sir or Madam],
>
> I am a researcher at Harvard University building an open dataset on Zambia's mining sector: > licences, production, value addition and supply chains: compiled entirely from published
> government and company sources.
>
> [Company] appears in our records as holding [N] licences covering [X] hectares in [district],
> [commodity]. I would value 20-30 minutes with someone in your team to check what we have and
> understand your perspective on [specific topic: value addition / export logistics / licensing].
>
> I am happy to share our entire record for [Company] in advance, and to reflect any corrections.
> The research is academic and non-commercial.
>
> [Name, affiliation, contact]

## 6. The 902 individual holders: route, not list

886 hold real mining licences; 599 are located to district, concentrated in **Mansa, Mkushi,
Serenje, Solwezi, Mumbwa, Mwinilunga**. Reach them through the district mining office and the
ASM association or cooperative for that district, not individually. Two practical reasons beyond
privacy: their contact details are not published anywhere, and any name-based match would be
unverifiable (Zambian personal names repeat heavily, you would approach the wrong person while
believing otherwise).

If interviews with artisanal miners are part of the research, **Harvard IRB review is required**,
and IRB-approved recruitment for informal-sector participants runs through exactly these
gatekeepers. The compliant route and the effective route are the same one.

## 7. What is still worth chasing for contacts

- Conference exhibitor directories (in progress): publish full contact blocks.
- Government Gazette company notices: registered addresses, advocates' details.
- ZPPA tender awards: supplier contacts.
- **UK Companies House** (free API): ~13 UK-parented holders: registered offices and director
  names in official capacity.
- **Facebook**: where Zambian SMEs actually publish phone and WhatsApp. Blocked to automation
  (HTTP 400); needs a real browser session. Highest-yield unexploited channel for the SME tail.
