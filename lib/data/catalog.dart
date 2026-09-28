library;

/// Sample marketplace data and the reference tables the app reasons over.
/// Wage figures follow State Labour Department notifications as of Aug 2026.

class Skill {
  final String id;
  final String wageCategory; // unskilled | semi_skilled | skilled
  final String
      category; // structure | finishing | services | machine | infra | technical | general
  final String displayName;
  final Map<String, String> localizedNames;
  const Skill(this.id, this.wageCategory, this.category, this.displayName,
      this.localizedNames);

  String name(String lang) => localizedNames[lang] ?? displayName;

  /// Job listings use the short trade name ("Helper"), while the picker shows
  /// the fuller label ("Helper / General Labourer"). Match on the short form.
  String get jobLabel => displayName.split(' /').first.trim();

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (id.replaceAll('_', ' ').contains(q)) return true;
    return localizedNames.values.any((n) => n.toLowerCase().contains(q));
  }
}

const List<Skill> kSkills = [
  Skill('mason', 'skilled', 'structure', 'Mason', {
    'en': 'Mason',
    'hi': 'राजमिस्त्री',
    'pa': 'ਰਾਜ ਮਿਸਤਰੀ',
    'ta': 'கல்சுவர் கட்டுபவர்',
    'te': 'రాతు సుံ నిర్మాత',
    'mr': 'दगडकाम मिस्त्री',
    'gu': 'પથ્થરના કામના કારીગર',
    'bn': 'রাজমিস্ত্রী',
    'ur': 'سنگتراش',
    'kn': 'ಸುಲ್ಲೆ ಕೆಲಸ ಮಾಡುವವನು',
    'ml': 'കല്ല്‌പണി ഉദ്യോഗി',
    'as': 'ভাঙ୍ଗ ମିସ୍ତ୍ରୀ',
    'or': 'ଇଁଟି କାମ ମିସ୍ତ୍ରୀ',
    'ks': 'سنگتراش',
    'sd': 'پٿر جو کام',
    'ne': 'पाथर मिस्त्री',
    'mni': 'সিলো কোन',
    'sat': 'ইট কাজের লোক',
    'sa': 'प्रस्तरकर्मी',
    'kok': 'दगड-काम मिस्तरी'
  }),
  Skill('helper', 'unskilled', 'general', 'Helper / General Labourer', {
    'en': 'Helper / General Labourer',
    'hi': 'हेल्पर / मजदूर',
    'pa': 'ਹੈਲਪਰ / ਮਜ਼ਦੂਰ',
    'ta': 'உதவியாளர் / பொதுவான தொழிலாளி',
    'te': 'సహాయకుడు / సాధారణ కార్మికుడు',
    'mr': 'मदत करणारा / साधारण मजूर',
    'gu': 'મદદનીશ / સામાન્ય કામદાર',
    'bn': 'সহায়ক / সাধারণ শ্রমিক',
    'ur': 'مددگار / عام مزدور',
    'kn': 'ಸಹಾಯಕ / ಸಾಮಾನ್ಯ ಕಾರ್ಮಿಕ',
    'ml': 'സഹായി / സാധാരണ തൊഴിലാളി',
    'as': 'সাহায্যকারী / সাধারণ কর্মী',
    'or': 'ସହାୟକ / ସାଧାରଣ ଶ୍ରମିକ',
    'ks': 'مددگار / عام مزدور',
    'sd': 'مدد ڪندڙ / عام لبورر',
    'ne': 'सहायक / साधारण श्रमिक',
    'mni': 'মদৎ নবা / সাধারণ শ্রমিক',
    'sat': 'সাহায্য করার লোক / সাধারণ কর্মী',
    'sa': 'सहायक / सामान्य श्रमिक',
    'kok': 'मदत करणारा / सामान्य श्रमिक'
  }),
  Skill('carpenter', 'skilled', 'structure', 'Carpenter', {
    'en': 'Carpenter',
    'hi': 'बढ़ई',
    'pa': 'ਤਰਖਾਣ',
    'ta': 'வட்டைக்கார',
    'te': 'కలిమి',
    'mr': 'बढई',
    'gu': 'લાકડીનો કારીગર',
    'bn': 'ছুতার',
    'ur': 'بڑھئی',
    'kn': 'ದಿ ಕೆಲಸ ಕೂಪರ್',
    'ml': 'തെരെഞ്ചാൻ',
    'as': 'ছুতার',
    'or': 'ଦରଜୀ',
    'ks': 'بڑھئی',
    'sd': 'لڪڙيءَ جو ڪم',
    'ne': 'कारपेन्टर',
    'mni': 'কাঠের কারিগর',
    'sat': 'কাঠের কারিগর',
    'sa': 'तक्षक',
    'kok': 'बढई'
  }),
  Skill('electrician', 'skilled', 'services', 'Electrician', {
    'en': 'Electrician',
    'hi': 'बिजली मिस्त्री',
    'pa': 'ਬਿਜਲੀ ਮਿਸਤਰੀ',
    'ta': 'மின்சாரக் கொத்தனார்',
    'te': 'విద్యుత్ మిస్త్రి',
    'mr': 'विजेचे मिस्त्री',
    'gu': 'બિજલીનો મિસ્ત્રી',
    'bn': 'বিদ্যুৎ মিস্ত্রী',
    'ur': 'الیکٹریشین',
    'kn': 'ಬಿದ್ಯುತ್ ಕಾರ್ಮಿಕ',
    'ml': 'വൈദ്യുതിക്ലിപ്പി',
    'as': 'বিজুলীয়া মিস্তিৰী',
    'or': 'ବିଦ୍ୟୁତ କାମୀ',
    'ks': 'الیکٹریشین',
    'sd': 'بجلي جو ڪم',
    'ne': 'विद्युत कारीगर',
    'mni': 'বিদ্যুৎ কর্মী',
    'sat': 'বিদ্যুৎ কর্মী',
    'sa': 'विद्युत्कर्मी',
    'kok': 'विजेचे मिस्त्री'
  }),
  Skill('plumber', 'skilled', 'services', 'Plumber', {
    'en': 'Plumber',
    'hi': 'प्लम्बर',
    'pa': 'ਪਲੰਬਰ',
    'ta': 'குழல் கற்றோ',
    'te': 'నాలుకలు మరమ్మత్ చేసేవాడు',
    'mr': 'पाणी पाईप मिस्त्री',
    'gu': 'પાઇપ કામનો મિસ્ત્રી',
    'bn': 'প্লাম্বার',
    'ur': 'پلمبر',
    'kn': 'ಪೈಪ್ ಲೈನ್ ಕಾರ್ಮಿಕ',
    'ml': 'പൈപ്പ് ത്രൈപ്പ',
    'as': 'নলী পাইপ মিস্তিৰী',
    'or': 'ପାଇପ ମିସ୍ତ୍ରୀ',
    'ks': 'پلمبر',
    'sd': 'پائپ جو ڪم',
    'ne': 'प्लम्बर',
    'mni': 'পাইপ কর্মী',
    'sat': 'পাইপের কর্মী',
    'sa': 'नलिका-कर्मी',
    'kok': 'पाणी पाईप मिस्त्री'
  }),
  Skill('painter', 'skilled', 'finishing', 'Painter', {
    'en': 'Painter',
    'hi': 'पेंटर',
    'pa': 'ਪੇਂਟਰ',
    'ta': 'வர்ணக்கொத்தனார்',
    'te': 'చిత్ర చేసేవాడు',
    'mr': 'रंगकाम मिस्त्री',
    'gu': 'રંગ કામનો મિસ્ત્રી',
    'bn': 'পেইন্টার',
    'ur': 'رنگ ساز',
    'kn': 'ರಂಗ ಕಾರ್ಮಿಕ',
    'ml': 'വര്ണ്ണത്തൊഴിലാളി',
    'as': 'ৰঙ দিওঁতা মিস্তিৰী',
    'or': 'ରଙ୍ଗଚିତ୍ରକ',
    'ks': 'رنگ ساز',
    'sd': 'رنگ جو ڪم',
    'ne': 'पेन्टर',
    'mni': 'রং কর্মী',
    'sat': 'রং করার কর্মী',
    'sa': 'रञ्जक',
    'kok': 'रंगकाम मिस्त्री'
  }),
  Skill('welder', 'skilled', 'structure', 'Welder / Fabricator', {
    'en': 'Welder / Fabricator',
    'hi': 'वेल्डर / फैब्रिकेटर',
    'pa': 'ਵੈਲਡਰ / ਫੈਬਰੀਕੇਟਰ',
    'ta': 'கொடுக்கும் பொருட்கள் தயாரிப்பவர்',
    'te': 'లోహ కలపట వాడు',
    'mr': 'वेल्डर / धातू कामकार',
    'gu': 'વેલ્ડર / ધાતુ કામનો કારીગર',
    'bn': 'ঝালাইকারী',
    'ur': 'ویلڈر',
    'kn': 'ಅಕ್ಷರಗಳನ್ನು ಹಿಡಿದುಕೊಳ್ಳುವ',
    'ml': 'വെൽഡിങ്കൾ',
    'as': 'লহা ধৰি লগাওঁতা',
    'or': 'ଲୋହା ଯୋଡୁ ଲୋକ',
    'ks': 'ویلڈر',
    'sd': 'لوھو جوڙڻ وارو',
    'ne': 'वेल्डर',
    'mni': 'লোহা যুক্ত কর্মী',
    'sat': 'লোহা যুক্ত করার কর্মী',
    'sa': 'तापधारी',
    'kok': 'वेल्डर / धातू कामकार'
  }),
  Skill('bar_bender', 'skilled', 'structure', 'Bar Bender / Steel Worker', {
    'en': 'Bar Bender / Steel Worker',
    'hi': 'सरिया बेंडर / लोहा मिस्त्री',
    'pa': 'ਸਰੀਆ ਬੈਂਡਰ / ਲੋਹਾ ਮਿਸਤਰੀ',
    'ta': 'கம்பி வளைக்கும் பணியாள்',
    'te': 'రాడ్ బెండర్',
    'mr': 'सरिया वाकणे वाला',
    'gu': 'લોહાની શાખાને વાળનાર',
    'bn': 'রড বেন্ডার',
    'ur': 'لوہے کی سلاخوں کو موڑنے والا',
    'kn': 'ರಡ್ ಬಾಗೆವ',
    'ml': 'വടി വിടവാണ്',
    'as': 'ৰড বেন্ডাৰ',
    'or': 'ରଡ ବେଣ୍ଡର',
    'ks': 'لوہے کی سلاخوں کو موڑنے والا',
    'sd': 'لوھے جو ليندو موڑڻ وارو',
    'ne': 'रड बेन्डर',
    'mni': 'লোহার রড বাঁকানো কর্মী',
    'sat': 'লোহার লাঠি বাঁকানো কর্মী',
    'sa': 'पृष्ठभागी',
    'kok': 'सरिया वाकणे वाला'
  }),
  Skill('shuttering', 'skilled', 'structure', 'Shuttering / Formwork Worker', {
    'en': 'Shuttering / Formwork Worker',
    'hi': 'शटरिंग / फॉर्मवर्क मजदूर',
    'pa': 'ਸ਼ਟਰਿੰਗ / ਫਾਰਮਵਰਕ ਮਜ਼ਦੂਰ',
    'ta': 'கட்ட வளையெழுதும் பணியாள்',
    'te': 'రూపం కట్టుకోవడం',
    'mr': 'शटरिंग / साचा बनाणे वाला',
    'gu': 'શટરિંગ કામનો મજૂર',
    'bn': 'শাটারিং কর্মী',
    'ur': 'شاٹرنگ کام',
    'kn': 'ಶಟರಿಂಗ್ ಕಾರ್ಮಿಕ',
    'ml': 'ഷട്ടറിംഗ് ജോലി',
    'as': 'শাটাৰিং কাম কৰা মজদুৰ',
    'or': 'ଫର୍ମୱାର୍କ ମଜଦୁର',
    'ks': 'شاٹرنگ کام',
    'sd': 'شاٽرنگ جو ڪم',
    'ne': 'शटरिंग कर्मी',
    'mni': 'শাটারিং কাজের কর্মী',
    'sat': 'শাটারিং কাজের কর্মী',
    'sa': 'संरचना-निर्माता',
    'kok': 'शटरिंग / साचा बनाणे वाला'
  }),
  Skill('tile_flooring', 'skilled', 'finishing', 'Tile & Flooring Worker', {
    'en': 'Tile & Flooring Worker',
    'hi': 'टाइल / फ्लोरिंग मिस्त्री',
    'pa': 'ਟਾਈਲ / ਫਲੋਰਿੰਗ ਮਿਸਤਰੀ',
    'ta': 'ஓடு போடும் பணியாள்',
    'te': 'టైల్ కుట్టుకు',
    'mr': 'टाईल / फर्श मिस्त्री',
    'gu': 'ટાઇલ / ફ્લોરિંગ મિસ્ત્રી',
    'bn': 'টাইল পাতানো কর্মী',
    'ur': 'ٹائل فرش کارکن',
    'kn': 'ಟೈಲ್ ಫ್ಲೋರಿಂಗ್ ಕಾರ್ಮಿಕ',
    'ml': 'താപ്പ് വെച്ചു കൊടുക്കുന്ന പ്രവൃത്തി',
    'as': 'টাইল লগাই দিওঁতা মিস্তিৰী',
    'or': 'ଟାଇଲ ଚଟଣୀ ମିସ୍ତ୍ରୀ',
    'ks': 'ٹائل فرش کارکن',
    'sd': 'ٽائل فرش جو ڪم',
    'ne': 'टाइल फ्लोरिंग कर्मी',
    'mni': 'টাইল মেঝে কর্মী',
    'sat': 'টাইল মেঝে কর্মী',
    'sa': 'पाषाण-पट्टिका-कारी',
    'kok': 'टाईल / फर्श मिस्त्री'
  }),
  Skill('waterproofing', 'semi_skilled', 'finishing', 'Waterproofing Worker', {
    'en': 'Waterproofing Worker',
    'hi': 'वॉटरप्रूफिंग मिस्त्री',
    'pa': 'ਵਾਟਰਪ੍ਰੂਫਿੰਗ ਮਿਸਤਰੀ',
    'ta': 'நீர் புகாமல் பாதுகாப்பு செய்பவர்',
    'te': 'నీటి ఆపటి కాం',
    'mr': 'वॉटरप्रूफिंग मिस्त्री',
    'gu': 'પાણી ના બુંધવાળો કામ',
    'bn': 'জলরোধী কর্মী',
    'ur': 'واٹر پروفنگ',
    'kn': 'ನೀರಿನ ನಿರೋಧಕ ಕಾರ್ಮಿಕ',
    'ml': 'ജലരോധിത്വ തൊഴിലാളി',
    'as': 'পানী নোসোবাৰ কাম',
    'or': 'ଜଳ ରୋଧୀ ମିସ୍ତ୍ରୀ',
    'ks': 'واٹر پروفنگ',
    'sd': 'پاڻي روڪڻ جو ڪم',
    'ne': 'जलरोधी कर्मी',
    'mni': 'জলরোধী কর্মী',
    'sat': 'জলরোধী কর্মী',
    'sa': 'जल-निरोधक-कर्मी',
    'kok': 'वॉटरप्रूफिंग मिस्त्री'
  }),
  Skill('pop_ceiling', 'skilled', 'finishing', 'POP / False Ceiling Worker', {
    'en': 'POP / False Ceiling Worker',
    'hi': 'पीओपी / फॉल्स सीलिंग मिस्त्री',
    'pa': 'ਪੀਓਪੀ / ਫਾਲਸ ਸੀਲਿੰਗ ਮਿਸਤਰੀ',
    'ta': 'சுரைப்பொருள் கூரை பணியாள்',
    'te': 'పిఓపీ ఛాయ కట్టుకోవటం',
    'mr': 'पीओपी / खोटी छत मिस्त्री',
    'gu': 'પીઓપી/ઝૂઠી છત મિસ્ત્રી',
    'bn': 'ফলস সিলিং কর্মী',
    'ur': 'POP سقف',
    'kn': 'ಕೃತ್ರಿಮ ಸಿಲಿಂಗ್ ಕಾರ್ಮಿಕ',
    'ml': 'പി.ഒ.പി സീലിംഗ് തൊഴിലാളി',
    'as': 'পিওপি ছাত মিস্তিৰী',
    'or': 'ପିଓପି ଛାତ ମିସ୍ତ୍ରୀ',
    'ks': 'POP سقف',
    'sd': 'پي او پي ڇت جو ڪم',
    'ne': 'पीओपी सीलिंग कर्मी',
    'mni': 'পিওপি সিলিং কর্মী',
    'sat': 'পিওপি সিলিং কর্মী',
    'sa': 'कृत्रिम-छद',
    'kok': 'पीओपी / खोटी छत मिस्त्री'
  }),
  Skill('glass_aluminium', 'skilled', 'finishing', 'Glass / Aluminium Worker', {
    'en': 'Glass / Aluminium Worker',
    'hi': 'शीशा / एल्युमिनियम मिस्त्री',
    'pa': 'ਸ਼ੀਸ਼ਾ / ਐਲੂਮੀਨੀਅਮ ਮਿਸਤਰੀ',
    'ta': 'கண்ணாடி / அலுமினியம் பணியாள்',
    'te': 'గాజు / అల్యూమినియం కట్టుకోవటం',
    'mr': 'काच / अलुमिनीयम मिस्त्री',
    'gu': 'કાચ / એલ્યુમિનિયમ મિસ્ત્રી',
    'bn': 'গ্লাস / অ্যালুমিনিয়াম কর্মী',
    'ur': 'شیشہ / ایلومنیم',
    'kn': 'ಗಾಜು / ಅಲುಮಿನಿಯಮ್ ಕಾರ್ಮಿಕ',
    'ml': 'ഗ്ലാസ്/അലുമിനിയം പ്രവൃത്തിയാൾ',
    'as': 'কাচ / এলুমিনিয়াম মিস্তিৰী',
    'or': 'ଗ୍ଲାସ / ଆଲୁମିନିୟମ ମିସ୍ତ୍ରୀ',
    'ks': 'شیشہ / ایلومنیم',
    'sd': 'شيشو / ايلومينيم جو ڪم',
    'ne': 'गिलास / एलुमिनियम कर्मी',
    'mni': 'গ্লাস / অ্যালুমিনিয়াম কর্মী',
    'sat': 'গ্লাস / অ্যালুমিনিয়াম কর্মী',
    'sa': 'कच/एल्यूमिनि-कर्मी',
    'kok': 'काच / अलुमिनीयम मिस्त्री'
  }),
  Skill('scaffolding', 'semi_skilled', 'structure', 'Scaffolding Worker', {
    'en': 'Scaffolding Worker',
    'hi': 'स्कैफोल्डिंग मजदूर',
    'pa': 'ਸਕੈਫੋਲਡਿੰਗ ਮਜ਼ਦੂਰ',
    'ta': 'ஏணி கட்டாணை தொழிலாளி',
    'te': 'చుట్టుపట్టు దిబ్బ కట్టుకోవటం',
    'mr': 'स्कॅफोल्डिंग मजूर',
    'gu': 'સ્કેફોલ્ડિંગ મજૂર',
    'bn': 'স্কাফোল্ডিং কর্মী',
    'ur': 'ڈھانچہ تیار کار',
    'kn': 'ಸ್ಕ್ಯಾಫೋಲ್ಡಿಂಗ್ ಕಾರ್ಮಿಕ',
    'ml': 'സ്കാഫോൾഡിംഗ് തൊഴിലാളി',
    'as': 'স্কাফোল্ডিং মজদুৰ',
    'or': 'ସ୍କାଫୋଲ୍ଡିଂ ମଜଦୁର',
    'ks': 'ڈھانچہ تیار کار',
    'sd': 'ڊھاچو بنائڻ والو',
    'ne': 'स्कैफोल्डिंग कामदार',
    'mni': 'স্কাফোল্ডিং কর্মী',
    'sat': 'স্কাফোল্ডিং কর্মী',
    'sa': 'निर्माण-संरचना-निर्माता',
    'kok': 'स्कॅफोल्डिंग मजूर'
  }),
  Skill('excavator', 'skilled', 'machine', 'Excavator / JCB Operator', {
    'en': 'Excavator / JCB Operator',
    'hi': 'जेसीबी ऑपरेटर',
    'pa': 'ਜੇਸੀਬੀ ਓਪਰੇਟਰ',
    'ta': 'ஆராய்வு / பயணி இயக்குனர்',
    'te': 'బుల్డోజర్ ఆపరేటర్',
    'mr': 'जेसीबी ऑपरेटर',
    'gu': 'જેસીબી ચાલક',
    'bn': 'খননকারী / জেসিবি অপারেটর',
    'ur': 'JCB آپریٹر',
    'kn': 'ಎಕ್ಸಕೇವೇಟರ್ ಆಪರೇಟರ್',
    'ml': 'ജെ.സി.ബി ഓപെരേറ്റർ',
    'as': 'জেসিবি অপাৰেটৰ',
    'or': 'JCB ଅପରେଟର',
    'ks': 'JCB آپریٹر',
    'sd': 'جي سي بي آپريٽر',
    'ne': 'जेसीबी अपरेटर',
    'mni': 'জেসিবি অপারেটর',
    'sat': 'জেসিবি অপারেটর',
    'sa': 'यांत्रिक-खनन-संचालक',
    'kok': 'जेसीबी ऑपरेटर'
  }),
  Skill('crane', 'skilled', 'machine', 'Crane Operator', {
    'en': 'Crane Operator',
    'hi': 'क्रेन ऑपरेटर',
    'pa': 'ਕਰੇਨ ਓਪਰੇਟਰ',
    'ta': 'கொலுசு இயக்குனர்',
    'te': 'క్రేన్ ఆపరేటర్',
    'mr': 'क्रेन ऑपरेटर',
    'gu': 'ક્રેન ચાલક',
    'bn': 'ক্রেন অপারেটর',
    'ur': 'کرین آپریٹر',
    'kn': 'ಕ್ರೇನ್ ಆಪರೇಟರ್',
    'ml': 'ക്രെയിൻ ഓപെരേറ്റർ',
    'as': 'ক্রেন অপাৰেটৰ',
    'or': 'କ୍ରେନ ଅପରେଟର',
    'ks': 'کرین آپریٹر',
    'sd': 'ڪرين آپريٽر',
    'ne': 'क्रेन अपरेटर',
    'mni': 'ক্রেন অপারেটর',
    'sat': 'ক্রেন অপারেটর',
    'sa': 'यांत्रिक-संचारक',
    'kok': 'क्रेन ऑपरेटर'
  }),
  Skill('machine_operator', 'skilled', 'machine', 'Other Machine Operator', {
    'en': 'Other Machine Operator',
    'hi': 'अन्य मशीन ऑपरेटर',
    'pa': 'ਹੋਰ ਮਸ਼ੀਨ ਓਪਰੇਟਰ',
    'ta': 'பிற இயந்திர இயக்குனர்',
    'te': 'ఇతర యంత్ర ఆపరేటర్',
    'mr': 'इतर मशीन ऑपरेटर',
    'gu': 'અન્ય મશીન ચાલક',
    'bn': 'অন্য মেশিন অপারেটর',
    'ur': 'دوسرے مشین آپریٹر',
    'kn': 'ಇತರ ಯಂತ್ರ ಆಪರೇಟರ್',
    'ml': 'മറ്റ് യന്ത്ര ഓപെരേറ്റർ',
    'as': 'আন্য মিছিন অপাৰেটৰ',
    'or': 'ଅନ୍ୟ ମେସିନ ଅପରେଟର',
    'ks': 'دوسرے مشین آپریٹر',
    'sd': 'ٻيا مشين آپريٽر',
    'ne': 'अन्य मशीन अपरेटर',
    'mni': 'অন্য মেশিন অপারেটর',
    'sat': 'অন্য মেশিন অপারেটর',
    'sa': 'अन्य-यंत्र-संचालक',
    'kok': 'इतर मशीन ऑपरेटर'
  }),
  Skill('road_worker', 'semi_skilled', 'infra', 'Road Worker', {
    'en': 'Road Worker',
    'hi': 'सड़क मजदूर',
    'pa': 'ਸੜਕ ਮਜ਼ਦੂਰ',
    'ta': 'சாலை தொழிலாளி',
    'te': 'రోడ్ కార్మికుడు',
    'mr': 'रस्ता मजूर',
    'gu': 'રોડ કામદાર',
    'bn': 'রাস্তা নির্মাণ কর্মী',
    'ur': 'سڑک کار مزدور',
    'kn': 'ರಸ್ತೆ ಕಾರ್ಮಿಕ',
    'ml': 'റോഡ് നിര്‍മ്മാണ പ്രവൃത്തിയാൾ',
    'as': 'পথ নিৰ্মাণ মজদুৰ',
    'or': 'ରାସ୍ତା ମଜଦୁର',
    'ks': 'سڑک کار مزدور',
    'sd': 'سڙڪ جو ڪم',
    'ne': 'सडक निर्माण कामदार',
    'mni': 'রাস্তা কর্মী',
    'sat': 'রাস্তা কর্মী',
    'sa': 'मार्ग-निर्माता',
    'kok': 'रस्ता मजूर'
  }),
  Skill('paving', 'semi_skilled', 'infra', 'Paving Worker', {
    'en': 'Paving Worker',
    'hi': 'पेविंग मजदूर',
    'pa': 'ਪੇਵਿੰਗ ਮਜ਼ਦੂਰ',
    'ta': 'கல்வெளி தொழிலாளி',
    'te': 'పేవింగ్ కార్మికుడు',
    'mr': 'पेव्हिंग मजूर',
    'gu': 'પેવિંગ કામદાર',
    'bn': 'নির্ধারিত ফুটপাথ কর্মী',
    'ur': 'سڑک کی بندش',
    'kn': 'ಮಾರ್ಗ ನಿರ್ಮಾಣ ಕಾರ್ಮಿಕ',
    'ml': 'പേവിംഗ് നിര്‍മ്മാണ പ്രവൃത്തിയാൾ',
    'as': 'পেভিং কাম মজদুৰ',
    'or': 'ଫୁଟପାଥ ମଜଦୁର',
    'ks': 'سڑک کی بندش',
    'sd': 'سڙڪ جي پاسن جو ڪم',
    'ne': 'पेभिङ् कामदार',
    'mni': 'প্যাভিং কর্মী',
    'sat': 'প্যাভিং কর্মী',
    'sa': 'पथप्रस्तरण-निर्माता',
    'kok': 'पेव्हिंग मजूर'
  }),
  Skill('drainage', 'semi_skilled', 'infra', 'Drainage / Sewerage Worker', {
    'en': 'Drainage / Sewerage Worker',
    'hi': 'नाली / सीवर मजदूर',
    'pa': 'ਨਾਲੀ / ਸੀਵਰ ਮਜ਼ਦੂਰ',
    'ta': 'கழிவு நீர் / மல நீர் நिकास கार्मिक',
    'te': 'డ్రేనేజ్ / సీవర్ కార్మికుడు',
    'mr': 'नाली / सांडवा मजूर',
    'gu': 'ડ્રેનેજ / સીવર કામદાર',
    'bn': 'নালা / সিওয়েজ কর্মী',
    'ur': 'نالیوں کی تعمیر',
    'kn': 'ಡ್ರೈನೇಜ್ / ಸೀವರ್ ಕಾರ್ಮಿಕ',
    'ml': 'ജലനിരോധനം/സെവേജ് പ്രവൃത്തിയാൾ',
    'as': 'নলা / সীবার মজদুৰ',
    'or': 'ନାଳୀ / ସଂଚୟ ମଜଦୁର',
    'ks': 'نالیوں کی تعمیر',
    'sd': 'نالي / سيوريج جو ڪم',
    'ne': 'ड्रेनेज / सीवर कामदार',
    'mni': 'নালা / সীবার কর্মী',
    'sat': 'নালা / সীবার কর্মী',
    'sa': 'नाली-निर्माता',
    'kok': 'नाली / सांडवा मजूर'
  }),
  Skill('earthwork', 'unskilled', 'infra', 'Earthwork Worker', {
    'en': 'Earthwork Worker',
    'hi': 'मिट्टी का काम',
    'pa': 'ਮਿੱਟੀ ਦਾ ਕੰਮ',
    'ta': 'மண் நிர்மாண தொழிலாளி',
    'te': 'భూమి చేతిలో ఖనన',
    'mr': 'मातीचा काम',
    'gu': 'માટીના કાર્ય કામદાર',
    'bn': 'মাটির কাজ',
    'ur': 'خاک کنی',
    'kn': 'ಮಣ್ಣಿನ ಕೆಲಸ',
    'ml': 'മണ്ണിൻ്റെ കൃത്യം പ്രവൃത്തിയാൾ',
    'as': 'মাটির কাম মজদুৰ',
    'or': 'ମାଟି ଖନନ ମଜଦୁର',
    'ks': 'خاک کنی',
    'sd': 'مٽي جو ڪم',
    'ne': 'माटो खनन कामदार',
    'mni': 'মাটির কাজ কর্মী',
    'sat': 'মাটির কাজ কর্মী',
    'sa': 'मृत्तिका-निर्माता',
    'kok': 'मातीचा काम'
  }),
  Skill('supervisor', 'skilled', 'technical', 'Site Supervisor / Foreman', {
    'en': 'Site Supervisor / Foreman',
    'hi': 'साइट सुपरवाइजर / मुकादम',
    'pa': 'ਸਾਈਟ ਸੁਪਰਵਾਈਜ਼ਰ / ਮੁਕਾਦਮ',
    'ta': 'தளம் பார்வையாளர் / தலைவர்',
    'te': 'సైట్ సూపర్‌వైజర్',
    'mr': 'साइट सुपरव्हाइजर / मुकादम',
    'gu': 'સાઇટ સુપરવાઇજર / ફોરમેન',
    'bn': 'সাইট পর্যবেক্ষক / তত্ত্বাবধায়ক',
    'ur': 'سائٹ سپروائزر',
    'kn': 'ಸೈಟ್ ಸೂಪರ್‌ವೈಸರ್',
    'ml': 'സൈറ്റ് സുപര്‍വൈസര്‍',
    'as': 'সাইট তদাৰকাকাৰী',
    'or': 'ସାଇଟ ତଦାରକକାରୀ',
    'ks': 'سائٹ سپروائزر',
    'sd': 'سائٽ نگران',
    'ne': 'साइट पर्यवेक्षक',
    'mni': 'সাইট তত্ত্বাবধায়ক',
    'sat': 'সাইট তত্ত্বাবধায়ক',
    'sa': 'स्थल-परीक्षक',
    'kok': 'साइट सुपरव्हाइजर / मुकादम'
  }),
  Skill('surveyor', 'skilled', 'technical', 'Surveyor', {
    'en': 'Surveyor',
    'hi': 'सर्वेयर',
    'pa': 'ਸਰਵੇਅਰ',
    'ta': 'அளப்பவர்',
    'te': 'సర్వేయర్',
    'mr': 'सर्वेक्षक',
    'gu': 'સર્વેક્ષણકાર',
    'bn': 'জরিপকারী',
    'ur': 'سروے کار',
    'kn': 'ಸರ್ವೇಷಕ',
    'ml': 'സര്‍വേ സ്ഥാനം',
    'as': 'জৰিপকাৰী',
    'or': 'ସର୍ବେକ୍ଷକ',
    'ks': 'سروے کار',
    'sd': 'سروي ڪندڙ',
    'ne': 'सर्वेक्षक',
    'mni': 'জরিপকারী',
    'sat': 'জরিপকারী',
    'sa': 'परिमापक',
    'kok': 'सर्वेक्षक'
  }),
  Skill('civil_technician', 'skilled', 'technical', 'Civil Technician', {
    'en': 'Civil Technician',
    'hi': 'सिविल टेक्नीशियन',
    'pa': 'ਸਿਵਲ ਤਕਨੀਸ਼ੀਅਨ',
    'ta': 'குடிசை தொழில்நுட்ப',
    'te': 'సివిల్ టెక్నీషియన్',
    'mr': 'सिव्हिल तंत्रज्ञ',
    'gu': 'સિવિલ ટેક્નિશિયન',
    'bn': 'সিভিল প্রযুক্তিবিদ',
    'ur': 'سول ٹیکنیشن',
    'kn': 'ಸಿವಿಲ್ ತಂತ್ರಜ್ಞ',
    'ml': 'സിവില്‍ ടെക്നിഷ്യൻ',
    'as': 'অসামৰিক প্রযুক্তিবিদ',
    'or': 'ସିଭିଲ ଟେକ୍ନିସିଆନ୍',
    'ks': 'سول ٹیکنیشن',
    'sd': 'سول ٽيڪنيشن',
    'ne': 'नागरिक प्रविधिज्ञ',
    'mni': 'সিভিল প্রযুক্তিবিদ',
    'sat': 'সিভিল প্রযুক্তিবিদ',
    'sa': 'नाग-तांत्रिक',
    'kok': 'सिव्हिल तंत्रज्ञ'
  }),
  Skill('other_skilled', 'skilled', 'general', 'Other Skilled Worker', {
    'en': 'Other Skilled Worker',
    'hi': 'अन्य कुशल मजदूर',
    'pa': 'ਹੋਰ ਹੁਨਰਮੰਦ ਮਜ਼ਦੂਰ',
    'ta': 'பிற திறன்படைத்த தொழிலாளி',
    'te': 'ఇతర నైపుణ్యసంపన్న కార్మికుడు',
    'mr': 'इतर कुशल मजूर',
    'gu': 'અન્ય કુશળ કામદાર',
    'bn': 'অন্য দক্ষ কর্মী',
    'ur': 'دیگر ماہر کارکن',
    'kn': 'ಇತರ ನುಣ್ಣತೆಯುಳ್ಳ ಕಾರ್ಮಿಕ',
    'ml': 'മറ്റ് വൈദഗ്‍ദ്ധ്യമുള്ള തൊഴിലാളി',
    'as': 'অন্য দক্ষ মজদুৰ',
    'or': 'ଅନ୍ୟ ଦକ୍ଷ ମଜଦୁର',
    'ks': 'دیگر ماہر کارکن',
    'sd': 'ٻيا ماهر ڪارمند',
    'ne': 'अन्य दक्ष कामदार',
    'mni': 'অন্য দক্ষ কর্মী',
    'sat': 'অন্য দক্ষ কর্মী',
    'sa': 'अन्य-कुशल-श्रमिक',
    'kok': 'इतर कुशल मजूर'
  }),
];

Skill? skillById(String? id) {
  if (id == null) return null;
  for (final s in kSkills) {
    if (s.id == id) return s;
  }
  return null;
}

String skillCategoryByDisplayName(String name) {
  for (final s in kSkills) {
    if (s.displayName == name || s.jobLabel == name) return s.wageCategory;
  }
  return 'skilled';
}

const Map<String, Map<String, String>> kSkillCategoryLabels = {
  'unskilled': {
    'en': 'Unskilled',
    'hi': 'अकुशल',
    'pa': 'ਅਕੁਸ਼ਲ',
    'ta': 'திறனற்ற',
    'te': 'అకుశల',
    'mr': 'अकुशल',
    'gu': 'અકુશળ',
    'bn': 'অদক্ষ',
    'ur': 'غیر ماہر',
    'kn': 'ನುಣ್ಣತೆಯಿಲ್ಲದ',
    'ml': 'നൈപുണ്യമില്ലാത്ത',
    'as': 'অদক্ষ',
    'or': 'ଅଦକ୍ଷ',
    'ks': 'غیر ماہر',
    'sd': 'غير ماهر',
    'ne': 'अकुशल',
    'mni': 'অদক্ষ',
    'sat': 'অদক্ষ',
    'sa': 'अकुशल',
    'kok': 'अकुशल'
  },
  'semi_skilled': {
    'en': 'Semi-Skilled',
    'hi': 'अर्ध-कुशल',
    'pa': 'ਅੱਧ-ਕੁਸ਼ਲ',
    'ta': 'ஜுவினாக்கிரி திறன்',
    'te': 'సెమీ-స్కిల్డ్',
    'mr': 'अर्ध-कुशल',
    'gu': 'અર્ધ-કુશળ',
    'bn': 'আধা-দক্ষ',
    'ur': 'نیم ماہر',
    'kn': 'ಅರ್ಧ-ನುಣ್ಣತೆಯುಳ್ಳ',
    'ml': 'അര്‍ദ്ധ-നൈപുണ്യമുള്ള',
    'as': 'আধা-দক্ষ',
    'or': 'ଅର୍ଦ୍ଧ-ଦକ୍ଷ',
    'ks': 'نیم ماہر',
    'sd': 'اڌو ماهر',
    'ne': 'आधा-कुशल',
    'mni': 'আধা-দক্ষ',
    'sat': 'আধা-দক্ষ',
    'sa': 'अर्ध-कुशल',
    'kok': 'अर्ध-कुशल'
  },
  'skilled': {
    'en': 'Skilled',
    'hi': 'कुशल',
    'pa': 'ਕੁਸ਼ਲ',
    'ta': 'திறன்கள் உள்ள',
    'te': 'నైపుణ్యం కలిగిన',
    'mr': 'कुशल',
    'gu': 'કુશળ',
    'bn': 'দক্ষ',
    'ur': 'ماہر',
    'kn': 'ನುಣ್ಣತೆಯುಳ್ಳ',
    'ml': 'നൈപുണ്യമുള്ള',
    'as': 'দক্ষ',
    'or': 'ଦକ୍ଷ',
    'ks': 'ماہر',
    'sd': 'ماهر',
    'ne': 'कुशल',
    'mni': 'দক্ষ',
    'sat': 'দক্ষ',
    'sa': 'कुशल',
    'kok': 'कुशल'
  },
};

String categoryLabel(String category, String lang) =>
    kSkillCategoryLabels[category]?[lang] ??
    kSkillCategoryLabels[category]?['en'] ??
    '';

class IdLabel {
  final String id;
  final Map<String, String> names;
  const IdLabel(this.id, this.names);
  String label(String lang) => names[lang] ?? names['en']!;
}

const List<IdLabel> kWorkTypes = [
  IdLabel('residential', {
    'en': 'Residential Construction',
    'hi': 'आवासीय निर्माण',
    'pa': 'ਰਿਹਾਇਸ਼ੀ ਉਸਾਰੀ'
  }),
  IdLabel('commercial', {
    'en': 'Commercial Construction',
    'hi': 'व्यावसायिक निर्माण',
    'pa': 'ਵਪਾਰਕ ਉਸਾਰੀ'
  }),
  IdLabel('renovation', {
    'en': 'Renovation / Repair',
    'hi': 'मरम्मत / नवीनीकरण',
    'pa': 'ਮੁਰੰਮਤ / ਨਵੀਨੀਕਰਨ'
  }),
  IdLabel('road_infra', {
    'en': 'Road & Infrastructure',
    'hi': 'सड़क और अवसंरचना',
    'pa': 'ਸੜਕ ਅਤੇ ਬੁਨਿਆਦੀ ਢਾਂਚਾ'
  }),
  IdLabel('plumb_elec', {
    'en': 'Plumbing / Electrical Work',
    'hi': 'प्लम्बिंग / बिजली का काम',
    'pa': 'ਪਲੰਬਿੰਗ / ਬਿਜਲੀ ਦਾ ਕੰਮ'
  }),
  IdLabel('interior',
      {'en': 'Interior Work', 'hi': 'इंटीरियर का काम', 'pa': 'ਅੰਦਰੂਨੀ ਕੰਮ'}),
  IdLabel('painting_wt', {'en': 'Painting', 'hi': 'पेंटिंग', 'pa': 'ਪੇਂਟਿੰਗ'}),
  IdLabel('flooring_wt', {
    'en': 'Flooring / Tiling',
    'hi': 'फ्लोरिंग / टाइलिंग',
    'pa': 'ਫਲੋਰਿੰਗ / ਟਾਈਲਿੰਗ'
  }),
  IdLabel('civil_structural', {
    'en': 'Civil / Structural Work',
    'hi': 'सिविल / संरचनात्मक काम',
    'pa': 'ਸਿਵਲ / ਢਾਂਚਾਗਤ ਕੰਮ'
  }),
  IdLabel('other_wt', {'en': 'Other', 'hi': 'अन्य', 'pa': 'ਹੋਰ'}),
];

const List<IdLabel> kClientTypes = [
  IdLabel('individual', {
    'en': 'Individual / Homeowner',
    'hi': 'व्यक्तिगत / घर का मालिक',
    'pa': 'ਵਿਅਕਤੀਗਤ / ਘਰ ਦਾ ਮਾਲਕ'
  }),
  IdLabel('business', {'en': 'Business', 'hi': 'व्यवसाय', 'pa': 'ਕਾਰੋਬਾਰ'}),
  IdLabel('property_owner',
      {'en': 'Property Owner', 'hi': 'संपत्ति मालिक', 'pa': 'ਜਾਇਦਾਦ ਦਾ ਮਾਲਕ'}),
  IdLabel('other_ct', {'en': 'Other', 'hi': 'अन्य', 'pa': 'ਹੋਰ'}),
];

const List<IdLabel> kContractorTypes = [
  IdLabel('individual', {
    'en': 'Individual Contractor',
    'hi': 'व्यक्तिगत ठेकेदार',
    'pa': 'ਵਿਅਕਤੀਗਤ ਠੇਕੇਦਾਰ'
  }),
  IdLabel('company', {
    'en': 'Construction Company',
    'hi': 'निर्माण कंपनी',
    'pa': 'ਉਸਾਰੀ ਕੰਪਨੀ'
  }),
  IdLabel('subcontractor',
      {'en': 'Subcontractor', 'hi': 'उप-ठेकेदार', 'pa': 'ਉਪ-ਠੇਕੇਦਾਰ'}),
];

/// Daily minimum wages by state/UT and skill category.
const Map<String, Map<String, double>> kMinWageTable = {
  'Andaman & Nicobar Islands': {
    'unskilled': 660,
    'semi_skilled': 726,
    'skilled': 792
  },
  'Andhra Pradesh': {'unskilled': 430, 'semi_skilled': 474, 'skilled': 522},
  'Arunachal Pradesh': {'unskilled': 394, 'semi_skilled': 435, 'skilled': 480},
  'Assam': {'unskilled': 405.52, 'semi_skilled': 448.52, 'skilled': 493.37},
  'Bihar': {'unskilled': 331, 'semi_skilled': 365, 'skilled': 403},
  'Chandigarh': {'unskilled': 401, 'semi_skilled': 442, 'skilled': 487},
  'Chhattisgarh': {'unskilled': 340, 'semi_skilled': 375, 'skilled': 414},
  'Delhi': {'unskilled': 783, 'semi_skilled': 863, 'skilled': 949},
  'Goa': {'unskilled': 412, 'semi_skilled': 454, 'skilled': 500},
  'Gujarat': {'unskilled': 324, 'semi_skilled': 357, 'skilled': 393},
  'Haryana': {'unskilled': 585.41, 'semi_skilled': 643.94, 'skilled': 708.34},
  'Himachal Pradesh': {'unskilled': 370, 'semi_skilled': 408, 'skilled': 449},
  'Jammu & Kashmir': {'unskilled': 371, 'semi_skilled': 409, 'skilled': 450},
  'Jharkhand': {'unskilled': 515, 'semi_skilled': 567, 'skilled': 624},
  'Karnataka': {'unskilled': 560, 'semi_skilled': 619, 'skilled': 681},
  'Kerala': {'unskilled': 737, 'semi_skilled': 811, 'skilled': 893},
  'Lakshadweep': {'unskilled': 565, 'semi_skilled': 623, 'skilled': 687},
  'Madhya Pradesh': {'unskilled': 335, 'semi_skilled': 369, 'skilled': 407},
  'Maharashtra': {'unskilled': 595, 'semi_skilled': 654, 'skilled': 720},
  'Manipur': {'unskilled': 364, 'semi_skilled': 401, 'skilled': 443},
  'Meghalaya': {'unskilled': 555, 'semi_skilled': 611, 'skilled': 672},
  'Mizoram': {'unskilled': 389, 'semi_skilled': 429, 'skilled': 474},
  'Nagaland': {'unskilled': 360, 'semi_skilled': 396, 'skilled': 437},
  'Odisha': {'unskilled': 472, 'semi_skilled': 520, 'skilled': 572},
  'Puducherry': {'unskilled': 433, 'semi_skilled': 478, 'skilled': 528},
  'Punjab': {'unskilled': 518.69, 'semi_skilled': 553.19, 'skilled': 592.84},
  'Rajasthan': {'unskilled': 259, 'semi_skilled': 272, 'skilled': 284},
  'Sikkim': {'unskilled': 412, 'semi_skilled': 454, 'skilled': 501},
  'Tamil Nadu': {'unskilled': 450, 'semi_skilled': 500, 'skilled': 560},
  'Telangana': {'unskilled': 615, 'semi_skilled': 677, 'skilled': 746},
  'Tripura': {'unskilled': 410, 'semi_skilled': 451, 'skilled': 497},
  'Uttar Pradesh': {
    'unskilled': 435.14,
    'semi_skilled': 478.65,
    'skilled': 526.52
  },
  'Uttarakhand': {'unskilled': 361, 'semi_skilled': 398, 'skilled': 438},
  'West Bengal': {'unskilled': 406, 'semi_skilled': 447, 'skilled': 492},
  'Ladakh': {'unskilled': 450, 'semi_skilled': 450, 'skilled': 450},
  'Dadra & Nagar Haveli and Daman & Diu': {
    'unskilled': 486.5,
    'semi_skilled': 497.5,
    'skilled': 507.5
  },
};

/// National floor when a state isn't in [kMinWageTable] — the Chief Labour
/// Commissioner (Central)'s Area C construction-worker VDA rates, effective
/// 1 April 2026 (order dated 30 March 2026), the lowest of the three central
/// area tiers and so the safe conservative default.
const Map<String, double> kDefaultMinWage = {
  'unskilled': 556,
  'semi_skilled': 650,
  'skilled': 781,
};

const _durationMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// Renders a job's work dates (ISO `yyyy-MM-dd` strings) and hours/day into
/// the same "18 Aug – 20 Sep 2026 · 8 hrs/day" text shown for live jobs.
String formatJobDuration(String startIso, String endIso, String hoursPerDay) {
  String? fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return '${d.day} ${_durationMonths[d.month - 1]} ${d.year}';
  }

  final startDate = DateTime.tryParse(startIso);
  final endDate = DateTime.tryParse(endIso);
  final start = fmt(startIso);
  final end = fmt(endIso);
  final dateText = start == null && end == null
      ? 'Ongoing'
      : (start != null && end != null ? '$start – $end' : (start ?? end)!);

  final parts = [dateText];
  if (startDate != null && endDate != null) {
    final days = endDate.difference(startDate).inDays + 1;
    if (days > 0) parts.add(_durationSpan(days));
  }
  final hrs = hoursPerDay.trim();
  if (hrs.isNotEmpty) parts.add('$hrs hrs/day');
  return parts.join(' · ');
}

/// "1 day"/"2 days", switching to "1 week"/"2 weeks" once the span is a
/// whole number of weeks, so a contractor sees "2 weeks" rather than "14 days".
String _durationSpan(int days) {
  if (days >= 7 && days % 7 == 0) {
    final weeks = days ~/ 7;
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
  }
  return '$days ${days == 1 ? 'day' : 'days'}';
}

/// A single date, formatted for display, or '' if [iso] doesn't parse — used
/// where Start Date and End Date are shown as their own, separate rows.
String formatJobDateLabel(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return '${d.day} ${_durationMonths[d.month - 1]} ${d.year}';
}

/// Just the length of the job ("2 weeks", "8 hrs/day") with no dates in it —
/// the counterpart to [formatJobDateLabel] for a Duration row shown next to
/// separate Start Date / End Date rows.
String formatJobDurationSpan(String startIso, String endIso, String hoursPerDay) {
  final startDate = DateTime.tryParse(startIso);
  final endDate = DateTime.tryParse(endIso);
  final parts = <String>[];
  if (startDate != null && endDate != null) {
    final days = endDate.difference(startDate).inDays + 1;
    if (days > 0) parts.add(_durationSpan(days));
  }
  final hrs = hoursPerDay.trim();
  if (hrs.isNotEmpty) parts.add('$hrs hrs/day');
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// The Factories Act, 1948 caps a working day at 12 hours (9 normal + 3
/// overtime, s.51/s.56/s.64) — the legal ceiling, not just a sanity check.
const int kMaxHoursPerDay = 12;

/// Metro areas that straddle state/UT lines but are one commutable region —
/// so "same city" search treats every city in a cluster as equivalent, even
/// though they're registered under different states. Chandigarh (UT),
/// Mohali and Zirakpur (Punjab) and Panchkula (Haryana) are, in practice,
/// one city split across three jurisdictions.
const List<List<String>> kMetroClusters = [
  ['Chandigarh', 'Mohali', 'Zirakpur', 'Panchkula'],
];

/// Case variants of one city name to query for — city is free-typed text
/// (there's a GPS-resolved path too, but the manual fallback lets anyone
/// enter "chandigarh", "CHANDIGARH", etc.), and Firestore's `whereIn` is an
/// exact, case-sensitive match. Covers the common cases without needing a
/// normalised-city field and a data backfill.
List<String> _caseVariants(String city) => {
      city,
      city.toLowerCase(),
      city.toUpperCase(),
      city[0].toUpperCase() + city.substring(1).toLowerCase(),
    }.toList();

/// The set of cities to match against for "same city" search — [city] and
/// its case variants, or every city (and their variants) in its metro
/// cluster when it belongs to one. Bounded well under Firestore's 30-value
/// `whereIn` limit even for the largest cluster.
List<String> citiesInClusterOf(String city) {
  if (city.isEmpty) return const [];
  for (final cluster in kMetroClusters) {
    if (cluster.any((c) => c.toLowerCase() == city.toLowerCase())) {
      return cluster.expand(_caseVariants).toList();
    }
  }
  return _caseVariants(city);
}

int minWageFor(String? state, String category) {
  final row = kMinWageTable[state] ?? kDefaultMinWage;
  final v = row[category] ?? row['skilled'] ?? row['unskilled'] ?? 0;
  return v.round();
}

/// India Post's postal-circle assignment, keyed by the first two digits of the
/// PIN code. Used to catch a PIN code that clearly can't belong to the state
/// the person picked (e.g. a Delhi PIN with Maharashtra selected).
const Map<String, List<String>> kPincodePrefixStates = {
  '11': ['Delhi'],
  '12': ['Haryana'],
  '13': ['Haryana'],
  '14': ['Punjab'],
  '15': ['Punjab'],
  '16': ['Punjab', 'Chandigarh'],
  '17': ['Himachal Pradesh'],
  '18': ['Jammu & Kashmir'],
  '19': ['Jammu & Kashmir', 'Ladakh'],
  '20': ['Uttar Pradesh'],
  '21': ['Uttar Pradesh'],
  '22': ['Uttar Pradesh'],
  '23': ['Uttar Pradesh'],
  '24': ['Uttar Pradesh'],
  '25': ['Uttar Pradesh'],
  '26': ['Uttar Pradesh'],
  '27': ['Uttar Pradesh'],
  '28': ['Uttarakhand'],
  '30': ['Rajasthan'],
  '31': ['Rajasthan'],
  '32': ['Rajasthan'],
  '33': ['Rajasthan'],
  '34': ['Rajasthan'],
  '36': ['Gujarat'],
  '37': ['Gujarat'],
  '38': ['Gujarat'],
  '39': ['Gujarat', 'Dadra & Nagar Haveli and Daman & Diu'],
  '40': ['Maharashtra', 'Goa'],
  '41': ['Maharashtra'],
  '42': ['Maharashtra'],
  '43': ['Maharashtra'],
  '44': ['Maharashtra'],
  '45': ['Madhya Pradesh'],
  '46': ['Madhya Pradesh'],
  '47': ['Madhya Pradesh'],
  '48': ['Madhya Pradesh'],
  '49': ['Chhattisgarh'],
  '50': ['Andhra Pradesh', 'Telangana'],
  '51': ['Andhra Pradesh', 'Telangana'],
  '52': ['Andhra Pradesh'],
  '53': ['Andhra Pradesh'],
  '56': ['Karnataka'],
  '57': ['Karnataka'],
  '58': ['Karnataka'],
  '59': ['Karnataka'],
  '60': ['Tamil Nadu'],
  '61': ['Tamil Nadu'],
  '62': ['Tamil Nadu'],
  '63': ['Tamil Nadu'],
  '64': ['Tamil Nadu', 'Puducherry'],
  '67': ['Kerala'],
  '68': ['Kerala'],
  '69': ['Kerala', 'Lakshadweep'],
  '70': ['West Bengal'],
  '71': ['West Bengal'],
  '72': ['West Bengal'],
  '73': ['West Bengal', 'Sikkim'],
  '74': ['West Bengal', 'Andaman & Nicobar Islands'],
  '75': ['Odisha'],
  '76': ['Odisha'],
  '77': ['Odisha'],
  '78': ['Assam'],
  '79': [
    'Arunachal Pradesh',
    'Nagaland',
    'Manipur',
    'Mizoram',
    'Tripura',
    'Meghalaya',
    'Assam'
  ],
  '80': ['Bihar'],
  '81': ['Bihar'],
  '82': ['Bihar'],
  '85': ['Bihar'],
  '83': ['Jharkhand'],
  '84': ['Jharkhand'],
};

/// True when the PIN code's postal circle is unknown or matches [state] — so
/// callers only warn on a PIN that clearly belongs elsewhere.
bool pincodeMatchesState(String pincode, String state) {
  if (pincode.length != 6 || state.isEmpty) return true;
  final states = kPincodePrefixStates[pincode.substring(0, 2)];
  if (states == null) return true;
  return states.contains(state);
}

/// True when the PIN's first two digits are a real India Post postal circle.
/// This covers essentially every valid Indian PIN even though the detailed
/// [kPinAreas] directory (which supplies the town/district autofill) only
/// has a small sample — so a real PIN outside that sample is still
/// recognised as valid and not flagged as wrong.
bool isKnownPincodePrefix(String pincode) =>
    pincode.length == 6 &&
    kPincodePrefixStates.containsKey(pincode.substring(0, 2));

const Map<String, int> kDefaultSkillWage = {
  'mason': 750,
  'helper': 450,
  'carpenter': 700,
  'electrician': 700,
  'plumber': 700,
  'painter': 620,
  'welder': 720,
  'bar_bender': 680,
  'shuttering': 650,
  'tile_flooring': 680,
  'waterproofing': 600,
  'pop_ceiling': 700,
  'glass_aluminium': 680,
  'scaffolding': 550,
  'excavator': 650,
  'crane': 700,
  'machine_operator': 640,
  'road_worker': 550,
  'paving': 550,
  'drainage': 550,
  'earthwork': 420,
  'supervisor': 900,
  'surveyor': 850,
  'civil_technician': 800,
  'other_skilled': 700,
};

const List<String> kStates = [
  // Highest-demand states/UTs for this app's current user base go first.
  'Haryana',
  'Punjab',
  'Chandigarh',
  'Delhi',
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman & Nicobar Islands',
  'Dadra & Nagar Haveli and Daman & Diu',
  'Jammu & Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

const Map<String, Map<String, String>> kStateNames = {
  'Andhra Pradesh': {'hi': 'आंध्र प्रदेश', 'pa': 'ਆਂਧਰਾ ਪ੍ਰਦੇਸ਼'},
  'Arunachal Pradesh': {'hi': 'अरुणाचल प्रदेश', 'pa': 'ਅਰੁਣਾਚਲ ਪ੍ਰਦੇਸ਼'},
  'Assam': {'hi': 'असम', 'pa': 'ਅਸਾਮ'},
  'Bihar': {'hi': 'बिहार', 'pa': 'ਬਿਹਾਰ'},
  'Chhattisgarh': {'hi': 'छत्तीसगढ़', 'pa': 'ਛੱਤੀਸਗੜ੍ਹ'},
  'Goa': {'hi': 'गोवा', 'pa': 'ਗੋਆ'},
  'Gujarat': {'hi': 'गुजरात', 'pa': 'ਗੁਜਰਾਤ'},
  'Haryana': {'hi': 'हरियाणा', 'pa': 'ਹਰਿਆਣਾ'},
  'Himachal Pradesh': {'hi': 'हिमाचल प्रदेश', 'pa': 'ਹਿਮਾਚਲ ਪ੍ਰਦੇਸ਼'},
  'Jharkhand': {'hi': 'झारखंड', 'pa': 'ਝਾਰਖੰਡ'},
  'Karnataka': {'hi': 'कर्नाटक', 'pa': 'ਕਰਨਾਟਕ'},
  'Kerala': {'hi': 'केरल', 'pa': 'ਕੇਰਲ'},
  'Madhya Pradesh': {'hi': 'मध्य प्रदेश', 'pa': 'ਮੱਧ ਪ੍ਰਦੇਸ਼'},
  'Maharashtra': {'hi': 'महाराष्ट्र', 'pa': 'ਮਹਾਰਾਸ਼ਟਰ'},
  'Manipur': {'hi': 'मणिपुर', 'pa': 'ਮਨੀਪੁਰ'},
  'Meghalaya': {'hi': 'मेघालय', 'pa': 'ਮੇਘਾਲਿਆ'},
  'Mizoram': {'hi': 'मिज़ोरम', 'pa': 'ਮਿਜ਼ੋਰਮ'},
  'Nagaland': {'hi': 'नागालैंड', 'pa': 'ਨਾਗਾਲੈਂਡ'},
  'Odisha': {'hi': 'ओडिशा', 'pa': 'ਓਡੀਸ਼ਾ'},
  'Punjab': {'hi': 'पंजाब', 'pa': 'ਪੰਜਾਬ'},
  'Rajasthan': {'hi': 'राजस्थान', 'pa': 'ਰਾਜਸਥਾਨ'},
  'Sikkim': {'hi': 'सिक्किम', 'pa': 'ਸਿੱਕਮ'},
  'Tamil Nadu': {'hi': 'तमिलनाडु', 'pa': 'ਤਮਿਲਨਾਡੂ'},
  'Telangana': {'hi': 'तेलंगाना', 'pa': 'ਤੇਲੰਗਾਨਾ'},
  'Tripura': {'hi': 'त्रिपुरा', 'pa': 'ਤ੍ਰਿਪੁਰਾ'},
  'Uttar Pradesh': {'hi': 'उत्तर प्रदेश', 'pa': 'ਉੱਤਰ ਪ੍ਰਦੇਸ਼'},
  'Uttarakhand': {'hi': 'उत्तराखंड', 'pa': 'ਉੱਤਰਾਖੰਡ'},
  'West Bengal': {'hi': 'पश्चिम बंगाल', 'pa': 'ਪੱਛਮੀ ਬੰਗਾਲ'},
  'Andaman & Nicobar Islands': {
    'hi': 'अंडमान और निकोबार द्वीप समूह',
    'pa': 'ਅੰਡੇਮਾਨ ਅਤੇ ਨਿਕੋਬਾਰ ਟਾਪੂ'
  },
  'Chandigarh': {'hi': 'चंडीगढ़', 'pa': 'ਚੰਡੀਗੜ੍ਹ'},
  'Dadra & Nagar Haveli and Daman & Diu': {
    'hi': 'दादरा और नगर हवेली और दमन और दीव',
    'pa': 'ਦਾਦਰਾ ਅਤੇ ਨਗਰ ਹਵੇਲੀ ਅਤੇ ਦਮਨ ਅਤੇ ਦੀਵ'
  },
  'Delhi': {'hi': 'दिल्ली', 'pa': 'ਦਿੱਲੀ'},
  'Jammu & Kashmir': {'hi': 'जम्मू और कश्मीर', 'pa': 'ਜੰਮੂ ਅਤੇ ਕਸ਼ਮੀਰ'},
  'Ladakh': {'hi': 'लद्दाख', 'pa': 'ਲੱਦਾਖ'},
  'Lakshadweep': {'hi': 'लक्षद्वीप', 'pa': 'ਲਕਸ਼ਦੀਪ'},
  'Puducherry': {'hi': 'पुडुचेरी', 'pa': 'ਪੁੱਡੂਚੇਰੀ'},
};

String stateName(String state, String lang) =>
    kStateNames[state]?[lang] ?? state;

class PinArea {
  final String city;
  final String district;
  final String state;
  const PinArea(this.city, this.district, this.state);
}

/// Stand-in for the India Post PIN directory: a PIN resolves town, district and
/// state, so a worker never has to know or spell their district.
const Map<String, PinArea> kPinAreas = {
  '110085': PinArea('Rohini', 'North West Delhi', 'Delhi'),
  '110017': PinArea('Saket', 'South Delhi', 'Delhi'),
  '201301': PinArea('Noida Sector 15', 'Gautam Buddha Nagar', 'Uttar Pradesh'),
  '226010': PinArea('Gomti Nagar', 'Lucknow', 'Uttar Pradesh'),
  '400053': PinArea('Andheri East', 'Mumbai Suburban', 'Maharashtra'),
  '411038': PinArea('Kothrud', 'Pune', 'Maharashtra'),
  '440015': PinArea('Wardhaman Nagar', 'Nagpur', 'Maharashtra'),
  '560066': PinArea('Whitefield', 'Bengaluru Urban', 'Karnataka'),
  '580020': PinArea('Vidyanagar', 'Dharwad', 'Karnataka'),
  '600096': PinArea('Perungudi', 'Chennai', 'Tamil Nadu'),
  '641014': PinArea('Peelamedu', 'Coimbatore', 'Tamil Nadu'),
  '500081': PinArea('Gachibowli', 'Hyderabad', 'Telangana'),
  '530013': PinArea('Gajuwaka', 'Visakhapatnam', 'Andhra Pradesh'),
  '700091': PinArea('Salt Lake', 'North 24 Parganas', 'West Bengal'),
  '800020': PinArea('Kankarbagh', 'Patna', 'Bihar'),
  '834004': PinArea('Hatia', 'Ranchi', 'Jharkhand'),
  '751024': PinArea('Patia', 'Khordha', 'Odisha'),
  '302018': PinArea('Malviya Nagar', 'Jaipur', 'Rajasthan'),
  '380015': PinArea('Vejalpur', 'Ahmedabad', 'Gujarat'),
  '395010': PinArea('Udhna', 'Surat', 'Gujarat'),
  '141001': PinArea('Civil Lines', 'Ludhiana', 'Punjab'),
  '160022': PinArea('Sector 22', 'Chandigarh', 'Chandigarh'),
  '122001': PinArea('Gurugram', 'Gurugram', 'Haryana'),
  '462016': PinArea('Kolar Road', 'Bhopal', 'Madhya Pradesh'),
  '492001': PinArea('Raipur', 'Raipur', 'Chhattisgarh'),
  '682024': PinArea('Kakkanad', 'Ernakulam', 'Kerala'),
  '781022': PinArea('Beltola', 'Kamrup Metropolitan', 'Assam'),
  '248001': PinArea('Dehradun', 'Dehradun', 'Uttarakhand'),
  '171001': PinArea('Shimla', 'Shimla', 'Himachal Pradesh'),
  '190001': PinArea('Srinagar', 'Srinagar', 'Jammu & Kashmir'),
};

class Job {
  final String id;
  final String title;
  final String skill;
  final String area;
  final String location;
  final String distance;
  final int wage;
  final String contractor;
  final String contractorPhone;
  final String postedAgo;
  final String duration;
  final String desc;
  /// The contractor's uid — distinct from [contractor], which is their
  /// display name. Applications must be filed against this, not the name,
  /// since firestore.rules checks the real uid.
  final String contractorUid;
  /// Start Date, End Date and the job's length, shown as their own rows on
  /// the detail screen. Empty for sample/seed jobs, which fall back to the
  /// combined [duration] string.
  final String startDateLabel;
  final String endDateLabel;
  final String durationSpan;
  /// Raw end date, when known — used to trigger the forced post-project
  /// rating prompt on the day the job ends. [endDateLabel] is the formatted
  /// display string; this is the same date, kept for comparison.
  final DateTime? endDate;
  /// The legal minimum wage captured once, at posting time, using the job's
  /// own location — not recomputed per viewer. Recomputing against whoever
  /// is currently looking at the job (their own state, which has nothing to
  /// do with where the job actually is) is what caused the same job to show
  /// as "below minimum" to some labourers and "fine" to others. 0 means
  /// unknown (sample/demo jobs), in which case callers fall back to a
  /// same-viewer estimate rather than claiming a wage violation that was
  /// never actually computed.
  final int minWageAtPost;
  const Job({
    required this.id,
    required this.title,
    required this.skill,
    required this.area,
    required this.location,
    required this.distance,
    required this.wage,
    required this.contractor,
    required this.contractorPhone,
    required this.postedAgo,
    required this.duration,
    required this.desc,
    this.contractorUid = '',
    this.startDateLabel = '',
    this.endDateLabel = '',
    this.durationSpan = '',
    this.endDate,
    this.minWageAtPost = 0,
  });
}

const List<Job> kJobs = [
  Job(
      id: 'j1',
      title: 'Site Mason needed',
      skill: 'Mason',
      area: 'Rohini, New Delhi',
      location:
          'Plot 14, Sector 7 Road, Pocket C, Rohini, New Delhi, Delhi 110085',
      distance: '2.3 km',
      wage: 750,
      contractor: 'Ramesh Constructions',
      contractorPhone: '98111 22001',
      postedAgo: '2h ago',
      duration: '18 Aug – 20 Sep 2026',
      desc:
          'Experienced mason required for a 3-storey residential site. Daily wage paid on time, tools provided.'),
  Job(
      id: 'j2',
      title: 'Electrician for wiring work',
      skill: 'Electrician',
      area: 'Andheri East, Mumbai',
      location:
          'Shree Krishna Apartments, Gundavali Road, Andheri East, Mumbai, Maharashtra 400069',
      distance: '4.1 km',
      wage: 650,
      contractor: 'Sunrise Builders',
      contractorPhone: '98222 33002',
      postedAgo: '5h ago',
      duration: '20 Aug – 5 Sep 2026',
      desc:
          'Need an electrician for internal wiring of a new apartment block. Minimum 2 years experience.'),
  Job(
      id: 'j3',
      title: 'Painter required urgently',
      skill: 'Painter',
      area: 'Whitefield, Bengaluru',
      location:
          'Villa 22, ITPL Main Road, Whitefield, Bengaluru, Karnataka 560066',
      distance: '1.8 km',
      wage: 620,
      contractor: 'Om Infra',
      contractorPhone: '98333 44003',
      postedAgo: '1h ago',
      duration: '17 Aug – 27 Aug 2026',
      desc:
          'Interior and exterior painting for a villa project. Material supplied by contractor.'),
  Job(
      id: 'j4',
      title: 'Helper for loading work',
      skill: 'Helper',
      area: 'Saket, New Delhi',
      location:
          'Site Gate 2, Press Enclave Road, Saket, New Delhi, Delhi 110017',
      distance: '3.5 km',
      wage: 480,
      contractor: 'Metro Developers',
      contractorPhone: '98444 55004',
      postedAgo: '8h ago',
      duration: '17 Aug – 24 Aug 2026',
      desc:
          'General helper needed for loading and unloading construction material at site.'),
  Job(
      id: 'j5',
      title: 'Plumber for bathroom fitting',
      skill: 'Plumber',
      area: 'Kothrud, Pune',
      location:
          'Shivtirtha Society, Karve Road, Kothrud, Pune, Maharashtra 411038',
      distance: '6.0 km',
      wage: 800,
      contractor: 'Green Homes',
      contractorPhone: '98555 66005',
      postedAgo: '1d ago',
      duration: '22 Aug – 10 Sep 2026',
      desc:
          'Bathroom fittings and pipeline work for a housing society. Experienced plumbers only.'),
  Job(
      id: 'j6',
      title: 'Carpenter for furniture work',
      skill: 'Carpenter',
      area: 'Salt Lake, Kolkata',
      location: 'AA Block, Salt Lake Sector 1, Kolkata, West Bengal 700064',
      distance: '2.0 km',
      wage: 740,
      contractor: 'Shree Interiors',
      contractorPhone: '98666 77006',
      postedAgo: '3h ago',
      duration: '19 Aug – 15 Oct 2026',
      desc:
          'Custom wardrobe and furniture work for a residential interior project.'),
];

/// Legal minimum used for the wage-comparison bars on a job, by skill.
const Map<String, int> kJobMinWage = {
  'Mason': 700,
  'Electrician': 750,
  'Plumber': 700,
  'Painter': 600,
  'Carpenter': 720,
  'Helper': 500,
};

class Worker {
  final String id;
  final String name;
  final String skill;
  final String experience;
  final String location;
  final double rating;
  final int wage;
  final String phone;
  final bool available;
  const Worker(this.id, this.name, this.skill, this.experience, this.location,
      this.rating, this.wage, this.phone,
      {this.available = true});
}

const List<Worker> kWorkers = [
  Worker('w1', 'Suresh Kumar', 'Mason', '8 yrs', 'Rohini, Delhi', 4.6, 750,
      '98765 43210'),
  Worker('w2', 'Anita Devi', 'Painter', '5 yrs', 'Whitefield, Bengaluru', 4.8,
      600, '98450 11223'),
  Worker('w3', 'Mohd Irfan', 'Electrician', '10 yrs', 'Andheri, Mumbai', 4.5,
      800, '99201 34567'),
  Worker('w4', 'Lakshmi Bai', 'Helper', '3 yrs', 'Saket, Delhi', 4.2, 500,
      '98111 22334'),
  Worker('w5', 'Ravi Shankar', 'Plumber', '6 yrs', 'Kothrud, Pune', 4.7, 780,
      '97654 98765'),
];

const Map<String, List<String>> kApplicantsByJob = {
  'sj1': ['w1', 'w4'],
  'sj2': ['w4', 'w2'],
};

class Contractor {
  final String id;
  final String name;
  final String location;
  final double rating;
  final String projects;
  final String phone;
  const Contractor(this.id, this.name, this.location, this.rating,
      this.projects, this.phone);
}

const List<Contractor> kContractors = [
  Contractor('c1', 'Ramesh Constructions', 'Rohini, Delhi', 4.5, '34 projects',
      '98111 22001'),
  Contractor('c2', 'Sunrise Builders', 'Andheri East, Mumbai', 4.2,
      '21 projects', '98222 33002'),
  Contractor('c3', 'Om Infra Pvt Ltd', 'Whitefield, Bengaluru', 4.8,
      '58 projects', '98333 44003'),
  Contractor('c4', 'Green Homes Developers', 'Kothrud, Pune', 4.6,
      '40 projects', '98555 66005'),
];

class VendorItem {
  final String id;
  final String item;
  final String vendor;
  final String location;
  final int price;
  final String unit;
  const VendorItem(
      this.id, this.item, this.vendor, this.location, this.price, this.unit);
}

const List<VendorItem> kVendorItems = [
  VendorItem('v1', 'Cement (OPC 53)', 'UltraTech Distributor', 'Rohini, Delhi',
      380, 'bag'),
  VendorItem('v2', 'Cement (OPC 53)', 'Shree Cement Depot', 'Rohini, Delhi',
      365, 'bag'),
  VendorItem('v3', 'Steel TMT Bar (Fe500)', 'Tata Steel Dealer',
      'Andheri, Mumbai', 62, 'kg'),
  VendorItem(
      'v4', 'Steel TMT Bar (Fe500)', 'JSW Dealer', 'Andheri, Mumbai', 59, 'kg'),
  VendorItem('v5', 'Bricks (Red clay)', 'Local Brick Kiln',
      'Whitefield, Bengaluru', 8, 'piece'),
  VendorItem('v6', 'Sand (River)', 'Krishna Sand Suppliers', 'Kothrud, Pune',
      1450, 'ton'),
];

class Review {
  final String id;
  final String name;
  final int rating;
  final String comment;
  const Review(this.id, this.name, this.rating, this.comment);
}

const List<Review> kReviews = [
  Review('r1', 'Ramesh Constructions', 5,
      'Suresh completed the masonry work on time and with great quality.'),
  Review('r2', 'Sunrise Builders', 4,
      'Reliable and hardworking. Would hire again.'),
  Review('r3', 'Om Infra', 5, 'Excellent attention to detail on every job.'),
];

const int kMaxAdditionalSkills = 5;
const int kMinAgeYears = 18;
