import 'dart:ui';

import 'country_names.dart';

/// Work with countries and territories consistently across your application.
///
/// Store [iso2] or [iso3] when saving a country; enum indexes and Dart member
/// names are not interchange identifiers. Before sending a code to another
/// service, check whether it accepts the extended identifiers documented on
/// those properties.
///
/// ```dart
/// final country = Country.fromIso2('br');
/// final code = country.iso3; // BRA
/// ```
///
/// See the [country guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/country.md)
/// for usage and constraints.
enum Country {
  // Metadata retrieved 2026-09-05. Membership: 249 ISO entries plus the
  // phone-supported AC, TA, and XK regions (252 entries total).
  // ISO membership:
  // https://salsa.debian.org/iso-codes-team/iso-codes/-/blob/d055275324963c9bce5882eaaa93024cf2bf7ed0/data/iso_3166-1.json
  // Every alpha-2/alpha-3 pair cross-checked against CLDR release 48,
  // including AC/ASC, TA/TAA, and XK/XKK. No package-invented codes.
  // https://github.com/unicode-org/cldr/blob/release-48/common/supplemental/supplementalData.xml
  // Primary calling codes: phone_numbers_parser 9.0.26,
  // lib/src/metadata/generated/metadata_by_iso_code.dart.
  // ITU reference: https://www.itu.int/oth/T0202.aspx?parent=T0202
  // SH retains 290; AC uses 247 and TA shares 290. NANP entries use 1 without
  // area codes. Parser coverage is not the calling-code authority: researched
  // supplements below provide reference defaults without adding validation
  // rules to PhoneNumber. Do not infer a code solely from a parent territory.
  // Supplements and remaining omissions reviewed 2026-09-05:
  // PN: the government's tourism department explicitly lists +64.
  // https://www.visitpitcairn.pn/
  // TF: ITU OB 1331 (2026), French Indian Ocean +262 numbering plan,
  // reserves NDC 26200 specifically for the French Southern/Antarctic Lands.
  // https://www.itu.int/dms_pub/itu-t/opb/sp/T-SP-OB.1331-2026-OAS-PDF-E.pdf
  // GS: conventional shared +500 default, listed in FCC's 2010 table (p. 8).
  // This is not a claim that all current on-island phones use +500: government
  // guidance lists +44 VoIP numbers at King Edward Point as well.
  // https://docs.fcc.gov/public/attachments/DA-10-1247A4_Rcd.pdf
  // https://gov.gs/wp-content/uploads/2026/01/Visiting-South-Georgia-25-26-FINAL.pdf
  // UM: shared +1 default; FCC lists Midway, Wake, Howland and Jarvis under 1.
  // Current Midway visitor information also publishes an explicit +1 number.
  // https://www.papahanaumokuakea.gov/wheritage/visitation.html
  // AQ remains null: Australian stations use +672, while USAP documents +64
  // routes to McMurdo/Scott Base. Neither supplies a continent-wide default.
  // https://www.antarctica.gov.au/site/assets/files/49433/expeditioner_handbook_february_2025_v2.pdf
  // https://www.usap.gov/USAPgov/travelAndDeployment/documents/FieldManual-Comms.pdf
  // BV: seasonal research/satellite facilities; HM: unoccupied islands.
  // No current general dialing default established from these authorities;
  // older country tables alone are insufficient to infer +47 or +61/+672.
  // https://npolar.no/en/norvegia/
  // https://www.antarctica.gov.au/antarctic-operations/stations-and-field-locations/heard-island/
  // On updates, recheck both references and refresh the independent ISO test
  // fixture from its source, never from this enum.

  /// Afghanistan (AF).
  afghanistan(iso2: 'AF', iso3: 'AFG', callingCode: '93'),

  /// Åland Islands (AX).
  alandIslands(iso2: 'AX', iso3: 'ALA', callingCode: '358'),

  /// Albania (AL).
  albania(iso2: 'AL', iso3: 'ALB', callingCode: '355'),

  /// Algeria (DZ).
  algeria(iso2: 'DZ', iso3: 'DZA', callingCode: '213'),

  /// American Samoa (AS).
  americanSamoa(iso2: 'AS', iso3: 'ASM', callingCode: '1'),

  /// Andorra (AD).
  andorra(iso2: 'AD', iso3: 'AND', callingCode: '376'),

  /// Angola (AO).
  angola(iso2: 'AO', iso3: 'AGO', callingCode: '244'),

  /// Anguilla (AI).
  anguilla(iso2: 'AI', iso3: 'AIA', callingCode: '1'),

  /// Antarctica (AQ).
  antarctica(iso2: 'AQ', iso3: 'ATA', callingCode: null),

  /// Antigua and Barbuda (AG).
  antiguaAndBarbuda(iso2: 'AG', iso3: 'ATG', callingCode: '1'),

  /// Argentina (AR).
  argentina(iso2: 'AR', iso3: 'ARG', callingCode: '54'),

  /// Armenia (AM).
  armenia(iso2: 'AM', iso3: 'ARM', callingCode: '374'),

  /// Aruba (AW).
  aruba(iso2: 'AW', iso3: 'ABW', callingCode: '297'),

  /// Ascension Island (AC); uses the extended identifiers AC and ASC.
  ascensionIsland(iso2: 'AC', iso3: 'ASC', callingCode: '247'),

  /// Australia (AU).
  australia(iso2: 'AU', iso3: 'AUS', callingCode: '61'),

  /// Austria (AT).
  austria(iso2: 'AT', iso3: 'AUT', callingCode: '43'),

  /// Azerbaijan (AZ).
  azerbaijan(iso2: 'AZ', iso3: 'AZE', callingCode: '994'),

  /// Bahamas (BS).
  bahamas(iso2: 'BS', iso3: 'BHS', callingCode: '1'),

  /// Bahrain (BH).
  bahrain(iso2: 'BH', iso3: 'BHR', callingCode: '973'),

  /// Bangladesh (BD).
  bangladesh(iso2: 'BD', iso3: 'BGD', callingCode: '880'),

  /// Barbados (BB).
  barbados(iso2: 'BB', iso3: 'BRB', callingCode: '1'),

  /// Belarus (BY).
  belarus(iso2: 'BY', iso3: 'BLR', callingCode: '375'),

  /// Belgium (BE).
  belgium(iso2: 'BE', iso3: 'BEL', callingCode: '32'),

  /// Belize (BZ).
  belize(iso2: 'BZ', iso3: 'BLZ', callingCode: '501'),

  /// Benin (BJ).
  benin(iso2: 'BJ', iso3: 'BEN', callingCode: '229'),

  /// Bermuda (BM).
  bermuda(iso2: 'BM', iso3: 'BMU', callingCode: '1'),

  /// Bhutan (BT).
  bhutan(iso2: 'BT', iso3: 'BTN', callingCode: '975'),

  /// Bolivia (BO).
  bolivia(iso2: 'BO', iso3: 'BOL', callingCode: '591'),

  /// Bonaire, Sint Eustatius and Saba (BQ).
  bonaireSintEustatiusAndSaba(iso2: 'BQ', iso3: 'BES', callingCode: '599'),

  /// Bosnia and Herzegovina (BA).
  bosniaAndHerzegovina(iso2: 'BA', iso3: 'BIH', callingCode: '387'),

  /// Botswana (BW).
  botswana(iso2: 'BW', iso3: 'BWA', callingCode: '267'),

  /// Bouvet Island (BV).
  bouvetIsland(iso2: 'BV', iso3: 'BVT', callingCode: null),

  /// Brazil (BR).
  brazil(iso2: 'BR', iso3: 'BRA', callingCode: '55'),

  /// British Indian Ocean Territory (IO).
  britishIndianOceanTerritory(iso2: 'IO', iso3: 'IOT', callingCode: '246'),

  /// Virgin Islands, British (VG).
  britishVirginIslands(iso2: 'VG', iso3: 'VGB', callingCode: '1'),

  /// Brunei Darussalam (BN).
  brunei(iso2: 'BN', iso3: 'BRN', callingCode: '673'),

  /// Bulgaria (BG).
  bulgaria(iso2: 'BG', iso3: 'BGR', callingCode: '359'),

  /// Burkina Faso (BF).
  burkinaFaso(iso2: 'BF', iso3: 'BFA', callingCode: '226'),

  /// Burundi (BI).
  burundi(iso2: 'BI', iso3: 'BDI', callingCode: '257'),

  /// Cabo Verde (CV).
  caboVerde(iso2: 'CV', iso3: 'CPV', callingCode: '238'),

  /// Cambodia (KH).
  cambodia(iso2: 'KH', iso3: 'KHM', callingCode: '855'),

  /// Cameroon (CM).
  cameroon(iso2: 'CM', iso3: 'CMR', callingCode: '237'),

  /// Canada (CA).
  canada(iso2: 'CA', iso3: 'CAN', callingCode: '1'),

  /// Cayman Islands (KY).
  caymanIslands(iso2: 'KY', iso3: 'CYM', callingCode: '1'),

  /// Central African Republic (CF).
  centralAfricanRepublic(iso2: 'CF', iso3: 'CAF', callingCode: '236'),

  /// Chad (TD).
  chad(iso2: 'TD', iso3: 'TCD', callingCode: '235'),

  /// Chile (CL).
  chile(iso2: 'CL', iso3: 'CHL', callingCode: '56'),

  /// China (CN).
  china(iso2: 'CN', iso3: 'CHN', callingCode: '86'),

  /// Christmas Island (CX).
  christmasIsland(iso2: 'CX', iso3: 'CXR', callingCode: '61'),

  /// Cocos (Keeling) Islands (CC).
  cocosKeelingIslands(iso2: 'CC', iso3: 'CCK', callingCode: '61'),

  /// Colombia (CO).
  colombia(iso2: 'CO', iso3: 'COL', callingCode: '57'),

  /// Comoros (KM).
  comoros(iso2: 'KM', iso3: 'COM', callingCode: '269'),

  /// Cook Islands (CK).
  cookIslands(iso2: 'CK', iso3: 'COK', callingCode: '682'),

  /// Costa Rica (CR).
  costaRica(iso2: 'CR', iso3: 'CRI', callingCode: '506'),

  /// Côte d'Ivoire (CI).
  coteDIvoire(iso2: 'CI', iso3: 'CIV', callingCode: '225'),

  /// Croatia (HR).
  croatia(iso2: 'HR', iso3: 'HRV', callingCode: '385'),

  /// Cuba (CU).
  cuba(iso2: 'CU', iso3: 'CUB', callingCode: '53'),

  /// Curaçao (CW).
  curacao(iso2: 'CW', iso3: 'CUW', callingCode: '599'),

  /// Cyprus (CY).
  cyprus(iso2: 'CY', iso3: 'CYP', callingCode: '357'),

  /// Czechia (CZ).
  czechia(iso2: 'CZ', iso3: 'CZE', callingCode: '420'),

  /// Congo, The Democratic Republic of the (CD).
  democraticRepublicOfTheCongo(iso2: 'CD', iso3: 'COD', callingCode: '243'),

  /// Denmark (DK).
  denmark(iso2: 'DK', iso3: 'DNK', callingCode: '45'),

  /// Djibouti (DJ).
  djibouti(iso2: 'DJ', iso3: 'DJI', callingCode: '253'),

  /// Dominica (DM).
  dominica(iso2: 'DM', iso3: 'DMA', callingCode: '1'),

  /// Dominican Republic (DO).
  dominicanRepublic(iso2: 'DO', iso3: 'DOM', callingCode: '1'),

  /// Ecuador (EC).
  ecuador(iso2: 'EC', iso3: 'ECU', callingCode: '593'),

  /// Egypt (EG).
  egypt(iso2: 'EG', iso3: 'EGY', callingCode: '20'),

  /// El Salvador (SV).
  elSalvador(iso2: 'SV', iso3: 'SLV', callingCode: '503'),

  /// Equatorial Guinea (GQ).
  equatorialGuinea(iso2: 'GQ', iso3: 'GNQ', callingCode: '240'),

  /// Eritrea (ER).
  eritrea(iso2: 'ER', iso3: 'ERI', callingCode: '291'),

  /// Estonia (EE).
  estonia(iso2: 'EE', iso3: 'EST', callingCode: '372'),

  /// Eswatini (SZ).
  eswatini(iso2: 'SZ', iso3: 'SWZ', callingCode: '268'),

  /// Ethiopia (ET).
  ethiopia(iso2: 'ET', iso3: 'ETH', callingCode: '251'),

  /// Falkland Islands (Malvinas) (FK).
  falklandIslands(iso2: 'FK', iso3: 'FLK', callingCode: '500'),

  /// Faroe Islands (FO).
  faroeIslands(iso2: 'FO', iso3: 'FRO', callingCode: '298'),

  /// Fiji (FJ).
  fiji(iso2: 'FJ', iso3: 'FJI', callingCode: '679'),

  /// Finland (FI).
  finland(iso2: 'FI', iso3: 'FIN', callingCode: '358'),

  /// France (FR).
  france(iso2: 'FR', iso3: 'FRA', callingCode: '33'),

  /// French Guiana (GF).
  frenchGuiana(iso2: 'GF', iso3: 'GUF', callingCode: '594'),

  /// French Polynesia (PF).
  frenchPolynesia(iso2: 'PF', iso3: 'PYF', callingCode: '689'),

  /// French Southern Territories (TF).
  frenchSouthernTerritories(iso2: 'TF', iso3: 'ATF', callingCode: '262'),

  /// Gabon (GA).
  gabon(iso2: 'GA', iso3: 'GAB', callingCode: '241'),

  /// Gambia (GM).
  gambia(iso2: 'GM', iso3: 'GMB', callingCode: '220'),

  /// Georgia (GE).
  georgia(iso2: 'GE', iso3: 'GEO', callingCode: '995'),

  /// Germany (DE).
  germany(iso2: 'DE', iso3: 'DEU', callingCode: '49'),

  /// Ghana (GH).
  ghana(iso2: 'GH', iso3: 'GHA', callingCode: '233'),

  /// Gibraltar (GI).
  gibraltar(iso2: 'GI', iso3: 'GIB', callingCode: '350'),

  /// Greece (GR).
  greece(iso2: 'GR', iso3: 'GRC', callingCode: '30'),

  /// Greenland (GL).
  greenland(iso2: 'GL', iso3: 'GRL', callingCode: '299'),

  /// Grenada (GD).
  grenada(iso2: 'GD', iso3: 'GRD', callingCode: '1'),

  /// Guadeloupe (GP).
  guadeloupe(iso2: 'GP', iso3: 'GLP', callingCode: '590'),

  /// Guam (GU).
  guam(iso2: 'GU', iso3: 'GUM', callingCode: '1'),

  /// Guatemala (GT).
  guatemala(iso2: 'GT', iso3: 'GTM', callingCode: '502'),

  /// Guernsey (GG).
  guernsey(iso2: 'GG', iso3: 'GGY', callingCode: '44'),

  /// Guinea (GN).
  guinea(iso2: 'GN', iso3: 'GIN', callingCode: '224'),

  /// Guinea-Bissau (GW).
  guineaBissau(iso2: 'GW', iso3: 'GNB', callingCode: '245'),

  /// Guyana (GY).
  guyana(iso2: 'GY', iso3: 'GUY', callingCode: '592'),

  /// Haiti (HT).
  haiti(iso2: 'HT', iso3: 'HTI', callingCode: '509'),

  /// Heard Island and McDonald Islands (HM).
  heardIslandAndMcDonaldIslands(iso2: 'HM', iso3: 'HMD', callingCode: null),

  /// Honduras (HN).
  honduras(iso2: 'HN', iso3: 'HND', callingCode: '504'),

  /// Hong Kong (HK).
  hongKong(iso2: 'HK', iso3: 'HKG', callingCode: '852'),

  /// Hungary (HU).
  hungary(iso2: 'HU', iso3: 'HUN', callingCode: '36'),

  /// Iceland (IS).
  iceland(iso2: 'IS', iso3: 'ISL', callingCode: '354'),

  /// India (IN).
  india(iso2: 'IN', iso3: 'IND', callingCode: '91'),

  /// Indonesia (ID).
  indonesia(iso2: 'ID', iso3: 'IDN', callingCode: '62'),

  /// Iran (IR).
  iran(iso2: 'IR', iso3: 'IRN', callingCode: '98'),

  /// Iraq (IQ).
  iraq(iso2: 'IQ', iso3: 'IRQ', callingCode: '964'),

  /// Ireland (IE).
  ireland(iso2: 'IE', iso3: 'IRL', callingCode: '353'),

  /// Isle of Man (IM).
  isleOfMan(iso2: 'IM', iso3: 'IMN', callingCode: '44'),

  /// Israel (IL).
  israel(iso2: 'IL', iso3: 'ISR', callingCode: '972'),

  /// Italy (IT).
  italy(iso2: 'IT', iso3: 'ITA', callingCode: '39'),

  /// Jamaica (JM).
  jamaica(iso2: 'JM', iso3: 'JAM', callingCode: '1'),

  /// Japan (JP).
  japan(iso2: 'JP', iso3: 'JPN', callingCode: '81'),

  /// Jersey (JE).
  jersey(iso2: 'JE', iso3: 'JEY', callingCode: '44'),

  /// Jordan (JO).
  jordan(iso2: 'JO', iso3: 'JOR', callingCode: '962'),

  /// Kazakhstan (KZ).
  kazakhstan(iso2: 'KZ', iso3: 'KAZ', callingCode: '7'),

  /// Kenya (KE).
  kenya(iso2: 'KE', iso3: 'KEN', callingCode: '254'),

  /// Kiribati (KI).
  kiribati(iso2: 'KI', iso3: 'KIR', callingCode: '686'),

  /// Kosovo (XK); uses the CLDR user-assigned identifiers XK and XKK.
  kosovo(iso2: 'XK', iso3: 'XKK', callingCode: '383'),

  /// Kuwait (KW).
  kuwait(iso2: 'KW', iso3: 'KWT', callingCode: '965'),

  /// Kyrgyzstan (KG).
  kyrgyzstan(iso2: 'KG', iso3: 'KGZ', callingCode: '996'),

  /// Laos (LA).
  laos(iso2: 'LA', iso3: 'LAO', callingCode: '856'),

  /// Latvia (LV).
  latvia(iso2: 'LV', iso3: 'LVA', callingCode: '371'),

  /// Lebanon (LB).
  lebanon(iso2: 'LB', iso3: 'LBN', callingCode: '961'),

  /// Lesotho (LS).
  lesotho(iso2: 'LS', iso3: 'LSO', callingCode: '266'),

  /// Liberia (LR).
  liberia(iso2: 'LR', iso3: 'LBR', callingCode: '231'),

  /// Libya (LY).
  libya(iso2: 'LY', iso3: 'LBY', callingCode: '218'),

  /// Liechtenstein (LI).
  liechtenstein(iso2: 'LI', iso3: 'LIE', callingCode: '423'),

  /// Lithuania (LT).
  lithuania(iso2: 'LT', iso3: 'LTU', callingCode: '370'),

  /// Luxembourg (LU).
  luxembourg(iso2: 'LU', iso3: 'LUX', callingCode: '352'),

  /// Macao (MO).
  macao(iso2: 'MO', iso3: 'MAC', callingCode: '853'),

  /// Madagascar (MG).
  madagascar(iso2: 'MG', iso3: 'MDG', callingCode: '261'),

  /// Malawi (MW).
  malawi(iso2: 'MW', iso3: 'MWI', callingCode: '265'),

  /// Malaysia (MY).
  malaysia(iso2: 'MY', iso3: 'MYS', callingCode: '60'),

  /// Maldives (MV).
  maldives(iso2: 'MV', iso3: 'MDV', callingCode: '960'),

  /// Mali (ML).
  mali(iso2: 'ML', iso3: 'MLI', callingCode: '223'),

  /// Malta (MT).
  malta(iso2: 'MT', iso3: 'MLT', callingCode: '356'),

  /// Marshall Islands (MH).
  marshallIslands(iso2: 'MH', iso3: 'MHL', callingCode: '692'),

  /// Martinique (MQ).
  martinique(iso2: 'MQ', iso3: 'MTQ', callingCode: '596'),

  /// Mauritania (MR).
  mauritania(iso2: 'MR', iso3: 'MRT', callingCode: '222'),

  /// Mauritius (MU).
  mauritius(iso2: 'MU', iso3: 'MUS', callingCode: '230'),

  /// Mayotte (YT).
  mayotte(iso2: 'YT', iso3: 'MYT', callingCode: '262'),

  /// Mexico (MX).
  mexico(iso2: 'MX', iso3: 'MEX', callingCode: '52'),

  /// Micronesia, Federated States of (FM).
  micronesia(iso2: 'FM', iso3: 'FSM', callingCode: '691'),

  /// Moldova (MD).
  moldova(iso2: 'MD', iso3: 'MDA', callingCode: '373'),

  /// Monaco (MC).
  monaco(iso2: 'MC', iso3: 'MCO', callingCode: '377'),

  /// Mongolia (MN).
  mongolia(iso2: 'MN', iso3: 'MNG', callingCode: '976'),

  /// Montenegro (ME).
  montenegro(iso2: 'ME', iso3: 'MNE', callingCode: '382'),

  /// Montserrat (MS).
  montserrat(iso2: 'MS', iso3: 'MSR', callingCode: '1'),

  /// Morocco (MA).
  morocco(iso2: 'MA', iso3: 'MAR', callingCode: '212'),

  /// Mozambique (MZ).
  mozambique(iso2: 'MZ', iso3: 'MOZ', callingCode: '258'),

  /// Myanmar (MM).
  myanmar(iso2: 'MM', iso3: 'MMR', callingCode: '95'),

  /// Namibia (NA).
  namibia(iso2: 'NA', iso3: 'NAM', callingCode: '264'),

  /// Nauru (NR).
  nauru(iso2: 'NR', iso3: 'NRU', callingCode: '674'),

  /// Nepal (NP).
  nepal(iso2: 'NP', iso3: 'NPL', callingCode: '977'),

  /// Netherlands (NL).
  netherlands(iso2: 'NL', iso3: 'NLD', callingCode: '31'),

  /// New Caledonia (NC).
  newCaledonia(iso2: 'NC', iso3: 'NCL', callingCode: '687'),

  /// New Zealand (NZ).
  newZealand(iso2: 'NZ', iso3: 'NZL', callingCode: '64'),

  /// Nicaragua (NI).
  nicaragua(iso2: 'NI', iso3: 'NIC', callingCode: '505'),

  /// Niger (NE).
  niger(iso2: 'NE', iso3: 'NER', callingCode: '227'),

  /// Nigeria (NG).
  nigeria(iso2: 'NG', iso3: 'NGA', callingCode: '234'),

  /// Niue (NU).
  niue(iso2: 'NU', iso3: 'NIU', callingCode: '683'),

  /// Norfolk Island (NF).
  norfolkIsland(iso2: 'NF', iso3: 'NFK', callingCode: '672'),

  /// North Korea (KP).
  northKorea(iso2: 'KP', iso3: 'PRK', callingCode: '850'),

  /// North Macedonia (MK).
  northMacedonia(iso2: 'MK', iso3: 'MKD', callingCode: '389'),

  /// Northern Mariana Islands (MP).
  northernMarianaIslands(iso2: 'MP', iso3: 'MNP', callingCode: '1'),

  /// Norway (NO).
  norway(iso2: 'NO', iso3: 'NOR', callingCode: '47'),

  /// Oman (OM).
  oman(iso2: 'OM', iso3: 'OMN', callingCode: '968'),

  /// Pakistan (PK).
  pakistan(iso2: 'PK', iso3: 'PAK', callingCode: '92'),

  /// Palau (PW).
  palau(iso2: 'PW', iso3: 'PLW', callingCode: '680'),

  /// Palestine, State of (PS).
  palestine(iso2: 'PS', iso3: 'PSE', callingCode: '970'),

  /// Panama (PA).
  panama(iso2: 'PA', iso3: 'PAN', callingCode: '507'),

  /// Papua New Guinea (PG).
  papuaNewGuinea(iso2: 'PG', iso3: 'PNG', callingCode: '675'),

  /// Paraguay (PY).
  paraguay(iso2: 'PY', iso3: 'PRY', callingCode: '595'),

  /// Peru (PE).
  peru(iso2: 'PE', iso3: 'PER', callingCode: '51'),

  /// Philippines (PH).
  philippines(iso2: 'PH', iso3: 'PHL', callingCode: '63'),

  /// Pitcairn (PN).
  pitcairn(iso2: 'PN', iso3: 'PCN', callingCode: '64'),

  /// Poland (PL).
  poland(iso2: 'PL', iso3: 'POL', callingCode: '48'),

  /// Portugal (PT).
  portugal(iso2: 'PT', iso3: 'PRT', callingCode: '351'),

  /// Puerto Rico (PR).
  puertoRico(iso2: 'PR', iso3: 'PRI', callingCode: '1'),

  /// Qatar (QA).
  qatar(iso2: 'QA', iso3: 'QAT', callingCode: '974'),

  /// Congo (CG).
  republicOfTheCongo(iso2: 'CG', iso3: 'COG', callingCode: '242'),

  /// Réunion (RE).
  reunion(iso2: 'RE', iso3: 'REU', callingCode: '262'),

  /// Romania (RO).
  romania(iso2: 'RO', iso3: 'ROU', callingCode: '40'),

  /// Russian Federation (RU).
  russia(iso2: 'RU', iso3: 'RUS', callingCode: '7'),

  /// Rwanda (RW).
  rwanda(iso2: 'RW', iso3: 'RWA', callingCode: '250'),

  /// Saint Barthélemy (BL).
  saintBarthelemy(iso2: 'BL', iso3: 'BLM', callingCode: '590'),

  /// Saint Helena (SH).
  ///
  /// The ISO identifiers SH and SHN cover Saint Helena, Ascension and Tristan
  /// da Cunha together. Use [ascensionIsland] or [tristanDaCunha] to address
  /// those phone regions individually.
  saintHelena(iso2: 'SH', iso3: 'SHN', callingCode: '290'),

  /// Saint Kitts and Nevis (KN).
  saintKittsAndNevis(iso2: 'KN', iso3: 'KNA', callingCode: '1'),

  /// Saint Lucia (LC).
  saintLucia(iso2: 'LC', iso3: 'LCA', callingCode: '1'),

  /// Saint Martin (French part) (MF).
  saintMartin(iso2: 'MF', iso3: 'MAF', callingCode: '590'),

  /// Saint Pierre and Miquelon (PM).
  saintPierreAndMiquelon(iso2: 'PM', iso3: 'SPM', callingCode: '508'),

  /// Saint Vincent and the Grenadines (VC).
  saintVincentAndTheGrenadines(iso2: 'VC', iso3: 'VCT', callingCode: '1'),

  /// Samoa (WS).
  samoa(iso2: 'WS', iso3: 'WSM', callingCode: '685'),

  /// San Marino (SM).
  sanMarino(iso2: 'SM', iso3: 'SMR', callingCode: '378'),

  /// Sao Tome and Principe (ST).
  saoTomeAndPrincipe(iso2: 'ST', iso3: 'STP', callingCode: '239'),

  /// Saudi Arabia (SA).
  saudiArabia(iso2: 'SA', iso3: 'SAU', callingCode: '966'),

  /// Senegal (SN).
  senegal(iso2: 'SN', iso3: 'SEN', callingCode: '221'),

  /// Serbia (RS).
  serbia(iso2: 'RS', iso3: 'SRB', callingCode: '381'),

  /// Seychelles (SC).
  seychelles(iso2: 'SC', iso3: 'SYC', callingCode: '248'),

  /// Sierra Leone (SL).
  sierraLeone(iso2: 'SL', iso3: 'SLE', callingCode: '232'),

  /// Singapore (SG).
  singapore(iso2: 'SG', iso3: 'SGP', callingCode: '65'),

  /// Sint Maarten (Dutch part) (SX).
  sintMaarten(iso2: 'SX', iso3: 'SXM', callingCode: '1'),

  /// Slovakia (SK).
  slovakia(iso2: 'SK', iso3: 'SVK', callingCode: '421'),

  /// Slovenia (SI).
  slovenia(iso2: 'SI', iso3: 'SVN', callingCode: '386'),

  /// Solomon Islands (SB).
  solomonIslands(iso2: 'SB', iso3: 'SLB', callingCode: '677'),

  /// Somalia (SO).
  somalia(iso2: 'SO', iso3: 'SOM', callingCode: '252'),

  /// South Africa (ZA).
  southAfrica(iso2: 'ZA', iso3: 'ZAF', callingCode: '27'),

  /// South Georgia and the South Sandwich Islands (GS).
  southGeorgiaAndTheSouthSandwichIslands(iso2: 'GS', iso3: 'SGS', callingCode: '500'),

  /// South Korea (KR).
  southKorea(iso2: 'KR', iso3: 'KOR', callingCode: '82'),

  /// South Sudan (SS).
  southSudan(iso2: 'SS', iso3: 'SSD', callingCode: '211'),

  /// Spain (ES).
  spain(iso2: 'ES', iso3: 'ESP', callingCode: '34'),

  /// Sri Lanka (LK).
  sriLanka(iso2: 'LK', iso3: 'LKA', callingCode: '94'),

  /// Sudan (SD).
  sudan(iso2: 'SD', iso3: 'SDN', callingCode: '249'),

  /// Suriname (SR).
  suriname(iso2: 'SR', iso3: 'SUR', callingCode: '597'),

  /// Svalbard and Jan Mayen (SJ).
  svalbardAndJanMayen(iso2: 'SJ', iso3: 'SJM', callingCode: '47'),

  /// Sweden (SE).
  sweden(iso2: 'SE', iso3: 'SWE', callingCode: '46'),

  /// Switzerland (CH).
  switzerland(iso2: 'CH', iso3: 'CHE', callingCode: '41'),

  /// Syria (SY).
  syria(iso2: 'SY', iso3: 'SYR', callingCode: '963'),

  /// Taiwan (TW).
  taiwan(iso2: 'TW', iso3: 'TWN', callingCode: '886'),

  /// Tajikistan (TJ).
  tajikistan(iso2: 'TJ', iso3: 'TJK', callingCode: '992'),

  /// Tanzania (TZ).
  tanzania(iso2: 'TZ', iso3: 'TZA', callingCode: '255'),

  /// Thailand (TH).
  thailand(iso2: 'TH', iso3: 'THA', callingCode: '66'),

  /// Timor-Leste (TL).
  timorLeste(iso2: 'TL', iso3: 'TLS', callingCode: '670'),

  /// Togo (TG).
  togo(iso2: 'TG', iso3: 'TGO', callingCode: '228'),

  /// Tokelau (TK).
  tokelau(iso2: 'TK', iso3: 'TKL', callingCode: '690'),

  /// Tonga (TO).
  tonga(iso2: 'TO', iso3: 'TON', callingCode: '676'),

  /// Trinidad and Tobago (TT).
  trinidadAndTobago(iso2: 'TT', iso3: 'TTO', callingCode: '1'),

  /// Tristan da Cunha (TA); uses the extended identifiers TA and TAA.
  tristanDaCunha(iso2: 'TA', iso3: 'TAA', callingCode: '290'),

  /// Tunisia (TN).
  tunisia(iso2: 'TN', iso3: 'TUN', callingCode: '216'),

  /// Türkiye (TR).
  turkiye(iso2: 'TR', iso3: 'TUR', callingCode: '90'),

  /// Turkmenistan (TM).
  turkmenistan(iso2: 'TM', iso3: 'TKM', callingCode: '993'),

  /// Turks and Caicos Islands (TC).
  turksAndCaicosIslands(iso2: 'TC', iso3: 'TCA', callingCode: '1'),

  /// Tuvalu (TV).
  tuvalu(iso2: 'TV', iso3: 'TUV', callingCode: '688'),

  /// Uganda (UG).
  uganda(iso2: 'UG', iso3: 'UGA', callingCode: '256'),

  /// Ukraine (UA).
  ukraine(iso2: 'UA', iso3: 'UKR', callingCode: '380'),

  /// United Arab Emirates (AE).
  unitedArabEmirates(iso2: 'AE', iso3: 'ARE', callingCode: '971'),

  /// United Kingdom (GB).
  unitedKingdom(iso2: 'GB', iso3: 'GBR', callingCode: '44'),

  /// United States (US).
  unitedStates(iso2: 'US', iso3: 'USA', callingCode: '1'),

  /// United States Minor Outlying Islands (UM).
  unitedStatesMinorOutlyingIslands(iso2: 'UM', iso3: 'UMI', callingCode: '1'),

  /// Virgin Islands, U.S. (VI).
  unitedStatesVirginIslands(iso2: 'VI', iso3: 'VIR', callingCode: '1'),

  /// Uruguay (UY).
  uruguay(iso2: 'UY', iso3: 'URY', callingCode: '598'),

  /// Uzbekistan (UZ).
  uzbekistan(iso2: 'UZ', iso3: 'UZB', callingCode: '998'),

  /// Vanuatu (VU).
  vanuatu(iso2: 'VU', iso3: 'VUT', callingCode: '678'),

  /// Holy See (Vatican City State) (VA).
  vaticanCity(iso2: 'VA', iso3: 'VAT', callingCode: '39'),

  /// Venezuela (VE).
  venezuela(iso2: 'VE', iso3: 'VEN', callingCode: '58'),

  /// Vietnam (VN).
  vietnam(iso2: 'VN', iso3: 'VNM', callingCode: '84'),

  /// Wallis and Futuna (WF).
  wallisAndFutuna(iso2: 'WF', iso3: 'WLF', callingCode: '681'),

  /// Western Sahara (EH).
  westernSahara(iso2: 'EH', iso3: 'ESH', callingCode: '212'),

  /// Yemen (YE).
  yemen(iso2: 'YE', iso3: 'YEM', callingCode: '967'),

  /// Zambia (ZM).
  zambia(iso2: 'ZM', iso3: 'ZMB', callingCode: '260'),

  /// Zimbabwe (ZW).
  zimbabwe(iso2: 'ZW', iso3: 'ZWE', callingCode: '263');

  const Country({required this.iso2, required this.iso3, required this.callingCode});

  /// An uppercase two-letter identifier for storage and lookup, such as `BR`.
  ///
  /// Uses ISO 3166-1 codes, including reserved AC and TA, and the CLDR
  /// user-assigned XK for Kosovo. Services requiring only officially assigned
  /// ISO codes may reject these three extended identifiers.
  final String iso2;

  /// An uppercase three-letter identifier for storage and lookup, such as `BRA`.
  ///
  /// Uses ISO 3166-1 codes and the CLDR mappings ASC for Ascension Island,
  /// TAA for Tristan da Cunha, and XKK for Kosovo. Services requiring only
  /// officially assigned ISO codes may reject these extended identifiers.
  final String iso3;

  /// The primary country calling code for a phone-input default, without `+`.
  ///
  /// For example, Brazil uses `55`. Shared numbering plans have shared codes:
  /// the United States and Canada both use `1`, without national area codes.
  /// Only the primary code is provided for territories with multiple codes.
  ///
  /// Returns `null` when no reliable primary mapping is available. This does
  /// not mean that phone service is unavailable. A calling code alone neither
  /// uniquely identifies a country nor validates a phone number.
  final String? callingCode;

  /// Returns this country's name in [locale] for a label or country picker.
  ///
  /// Works synchronously and offline. Available translations and wording can
  /// vary by platform and operating-system version. When a translation is
  /// unavailable, returns an English name.
  ///
  /// The returned name is for presentation only. Store and exchange [iso2]
  /// or [iso3] when a stable country identifier is required.
  String displayName(Locale locale) => CountryNames.instance.displayName(iso2, locale.toLanguageTag());

  static final Map<String, Country> _byIso2 = {for (final country in values) country.iso2: country};
  static final Map<String, Country> _byIso3 = {for (final country in values) country.iso3: country};
  static final _iso2Pattern = RegExp(r'^[a-zA-Z]{2}$');
  static final _iso3Pattern = RegExp(r'^[a-zA-Z]{3}$');

  /// Finds a country by its two-letter identifier, such as `BR`.
  ///
  /// Accepts the extended identifiers documented on [iso2], ASCII letters in
  /// either case, and surrounding whitespace. Throws a [FormatException] for
  /// malformed or unsupported codes. Use [tryFromIso2] when an unknown code
  /// should return `null` instead.
  static Country fromIso2(String code) =>
      tryFromIso2(code) ?? (throw FormatException('Unsupported two-letter country identifier', code));

  /// Finds a country by its three-letter identifier, such as `BRA`.
  ///
  /// Accepts the extended identifiers documented on [iso3], ASCII letters in
  /// either case, and surrounding whitespace. Throws a [FormatException] for
  /// malformed or unsupported codes. Use [tryFromIso3] when an unknown code
  /// should return `null` instead.
  static Country fromIso3(String code) =>
      tryFromIso3(code) ?? (throw FormatException('Unsupported three-letter country identifier', code));

  /// Finds a country by its two-letter identifier, or returns `null`.
  ///
  /// Accepts the extended identifiers documented on [iso2], ASCII letters in
  /// either case, and surrounding whitespace. Malformed or unsupported codes
  /// return `null`.
  static Country? tryFromIso2(String code) {
    final trimmed = code.trim();
    if (!_iso2Pattern.hasMatch(trimmed)) return null;
    return _byIso2[trimmed.toUpperCase()];
  }

  /// Finds a country by its three-letter identifier, or returns `null`.
  ///
  /// Accepts the extended identifiers documented on [iso3], ASCII letters in
  /// either case, and surrounding whitespace. Malformed or unsupported codes
  /// return `null`.
  static Country? tryFromIso3(String code) {
    final trimmed = code.trim();
    if (!_iso3Pattern.hasMatch(trimmed)) return null;
    return _byIso3[trimmed.toUpperCase()];
  }
}
