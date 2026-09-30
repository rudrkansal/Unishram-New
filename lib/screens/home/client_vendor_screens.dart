import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/catalog.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/feed_builder.dart';
import '../../widgets/search_tier_bar.dart';
import '../coming_soon_screen.dart';
import 'contractor_screens.dart';

/// Client search — toggle between hiring a contractor and hiring workers.
class ClientSearch extends StatelessWidget {
  const ClientSearch({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final contractors = app.searchMode == 'contractors';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Row(
            children: [
              Expanded(
                child: Pill(t['contractors'],
                    selected: contractors,
                    onTap: () => context.app
                        .update(() => app.searchMode = 'contractors')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pill(t['workers'],
                    selected: !contractors,
                    onTap: () =>
                        context.app.update(() => app.searchMode = 'workers')),
              ),
            ],
          ),
        ),
        // The "workers" branch below embeds ContractorFind, which already
        // renders its own SearchTierBar — showing one here too would stack
        // two of them for that mode.
        if (contractors)
          SearchTierBar(
            tier: app.contractorSearchTier,
            onWiden: () => context.app.widenContractorSearch(),
            onReset: () => context.app.resetContractorSearch(),
          ),
        Expanded(
          child: contractors
              ? FeedBuilder<Contractor>(
                  stream: app.contractorFeed(),
                  emptyText: t['noContractorsYet'],
                  builder: (context, list) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return SurfaceCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () =>
                            context.app.viewContractor(c.id, contractor: c),
                        child: Row(
                          children: [
                            Avatar(initialsOf(c.name)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: C.text)),
                                  const SizedBox(height: 2),
                                  Text('${c.location} · ${c.projects}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: C.textSecondary)),
                                  const SizedBox(height: 6),
                                  Text('★ ${c.rating}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: C.accent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : const ContractorFind(forClient: true),
        ),
      ],
    );
  }
}

class ClientContractorDetail extends StatelessWidget {
  const ClientContractorDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final c = app.selectedContractor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        Column(
          children: [
            Avatar(initialsOf(c.name), size: 76),
            const SizedBox(height: 10),
            Text(c.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
            const SizedBox(height: 6),
            Text('${c.location} · ${c.projects}',
                style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            const SizedBox(height: 10),
            Text('★ ${c.rating}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: C.text)),
          ],
        ),
        const SizedBox(height: 24),
        // No direct chat from the Find screens (chat is job-scoped), and other
        // users' phones are not on public profiles — Contact only appears where
        // a phone is actually available (offline sample data).
        if (c.phone.isNotEmpty)
          PrimaryButton(t['contact'],
              onTap: () => context.app.openContact(ContactTarget(
                    name: c.name,
                    subtitle: '${c.location} · ${c.projects}',
                    phone: c.phone,
                  ))),
      ],
    );
  }
}

/// Material price comparison across vendors, sortable by price.
class VendorPrices extends StatelessWidget {
  const VendorPrices({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoonScreen(showBack: false);
}

class ClientProfile extends StatelessWidget {
  const ClientProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Column(
          children: [
            Avatar(app.roleInitial, size: 76, imagePath: app.lp.profilePicture),
            const SizedBox(height: 8),
            Text(app.displayName,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: C.text)),
            if (app.lp.phoneVerified) ...[
              const SizedBox(height: 8),
              BadgePill(t['verifiedMobileBadge'],
                  background: C.okBg, color: C.ok),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(t['phoneNumber'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.lp.mobileNumber,
          digitsOnly: true,
          maxLength: 10,
          fontSize: 14,
          keyboardType: TextInputType.phone,
          onChanged: (v) => context.app.update(() => app.lp.mobileNumber = v),
        ),
        const SizedBox(height: 24),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.app.go(Screen.langSelect),
          child: Text(app.t['changeLanguage'] ?? 'Change Language',
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.textMid)),
        ),
        const SizedBox(height: 8),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        const AccountActions(),
      ],
    );
  }
}

class VendorListings extends StatefulWidget {
  const VendorListings({super.key});

  @override
  State<VendorListings> createState() => _VendorListingsState();
}

class _VendorListingsState extends State<VendorListings> {
  String _name = '';
  String _price = '';
  String _unit = '';

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: FeedBuilder<Listing>(
            stream: app.myListingsFeed(),
            emptyText: t['noListingsYet'],
            builder: (context, listings) => Column(
              children: [
                for (final v in listings)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: C.surface,
                      border: Border.all(color: C.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(v.item,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: C.text)),
                        ),
                        Text('₹${inr(v.price)}/${v.unit}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: C.accent)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: C.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['addItem'],
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: C.textSecondary)),
              const SizedBox(height: 10),
              AppTextField(
                initial: _name,
                hint: t['itemName'],
                fontSize: 13,
                onChanged: (v) => setState(() => _name = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      initial: _price,
                      hint: t['price'],
                      digitsOnly: true,
                      maxLength: 7,
                      fontSize: 13,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => _price = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppTextField(
                      initial: _unit,
                      hint: t['unit'],
                      fontSize: 13,
                      onChanged: (v) => setState(() => _unit = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                t['addItem'],
                enabled: _name.trim().isNotEmpty && _price.isNotEmpty,
                onTap: () {
                  context.app.addListingLive(_name, _price, _unit);
                  setState(() {
                    _name = '';
                    _price = '';
                    _unit = '';
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VendorProfile extends StatelessWidget {
  const VendorProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: Avatar(app.roleInitial, size: 76)),
        const SizedBox(height: 16),
        Text(t['shopName'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.shopName,
          fontSize: 14,
          onChanged: (v) => context.app.update(() => app.shopName = v),
        ),
        const SizedBox(height: 16),
        Text(t['location'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.shopLocation,
          fontSize: 14,
          onChanged: (v) => context.app.update(() => app.shopLocation = v),
        ),
        const SizedBox(height: 16),
        Text(t['phoneNumber'], style: T.label),
        const SizedBox(height: 6),
        AppTextField(
          initial: app.lp.mobileNumber,
          digitsOnly: true,
          maxLength: 10,
          fontSize: 14,
          keyboardType: TextInputType.phone,
          onChanged: (v) => context.app.update(() => app.lp.mobileNumber = v),
        ),
        const SizedBox(height: 24),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.app.go(Screen.langSelect),
          child: Text(app.t['changeLanguage'] ?? 'Change Language',
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: C.textMid)),
        ),
        const SizedBox(height: 8),
        const Divider(color: C.border),
        const SizedBox(height: 8),
        const AccountActions(),
      ],
    );
  }
}

/// One-to-one thread between a worker and a contractor about a job.
class ChatThread extends StatefulWidget {
  const ChatThread({super.key});

  @override
  State<ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<ChatThread> {
  final _controller = TextEditingController();

  // Calling app.messageFeed() fresh inside StreamBuilder's `stream:` arg
  // would hand it a brand-new Firestore subscription on every rebuild —
  // context.appWatch rebuilds this whenever any app state changes, so the
  // stream would keep resetting to "waiting" before ever delivering data.
  // Caching it here, keyed by the current thread, keeps one subscription
  // alive across rebuilds.
  Stream<List<ChatMessage>>? _stream;
  String? _streamKey;
  // jobById only knows locally-posted + demo jobs, so it misses the job
  // whenever the OTHER party in this chat is the one who posted it. A live
  // lookup keeps the job-title subtitle showing for both sides.
  Stream<Job?>? _jobStream;
  String? _jobStreamKey;
  Stream<bool>? _rejectedStream;
  String? _rejectedStreamKey;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final t = app.t;
    final key = app.currentThreadId ?? '${app.chatJobId}:${app.chatPeerId}';
    if (_streamKey != key) {
      _streamKey = key;
      _stream = app.messageFeed();
    }
    if (_jobStreamKey != app.chatJobId) {
      _jobStreamKey = app.chatJobId;
      _jobStream = app.chatJobId == null
          ? null
          : app.jobStream(app.chatJobId!);
    }
    if (_rejectedStreamKey != key) {
      _rejectedStreamKey = key;
      _rejectedStream = app.chatApplicationRejected();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: C.surface,
            border: Border(bottom: BorderSide(color: C.border)),
          ),
          child: Row(
            children: [
              Avatar(initialsOf(app.chatWithName), size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.chatWithName,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: C.text)),
                    if (_jobStream != null)
                      StreamBuilder<Job?>(
                        stream: _jobStream,
                        builder: (context, snapshot) {
                          final job = snapshot.data;
                          if (job == null) return const SizedBox.shrink();
                          return Text(job.title,
                              style: const TextStyle(
                                  fontSize: 11.5, color: C.mutedSoft));
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF6F4EF),
            // Chat bubbles keep a fixed side for "my" messages regardless of
            // the viewer's language direction — like WhatsApp, Telegram etc.
            // Without this, CrossAxisAlignment.start/end below get mirrored
            // by the ambient RTL Directionality for Urdu/Kashmiri/Sindhi
            // users, making sent/received bubbles swap or look wrong.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: StreamBuilder<List<ChatMessage>>(
              stream: _stream,
              builder: (context, snapshot) {
                final app = context.appWatch;
                var messages = snapshot.data ?? const <ChatMessage>[];
                // Filter out messages from blocked users
                messages = messages.where((m) {
                  final senderId = m.senderId;
                  return senderId == null || !app.blockedUserIds.contains(senderId);
                }).toList();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    return Column(
                      crossAxisAlignment: m.mine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: m.mine ? C.accent : C.surface,
                            border: m.mine ? null : Border.all(color: C.border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(m.text,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: m.mine ? Colors.white : C.text)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(m.time,
                              style: const TextStyle(
                                  fontSize: 10.5, color: C.muted)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ),
          ),
        ),
        StreamBuilder<bool>(
          stream: _rejectedStream,
          builder: (context, snapshot) {
            final rejected = snapshot.data ?? false;
            if (rejected) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: C.surface,
                  border: Border(top: BorderSide(color: C.border)),
                ),
                child: Text(t['chatClosedRejected'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: C.textSecondary)),
              );
            }
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: C.surface,
                border: Border(top: BorderSide(color: C.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: 13.5, color: C.text),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: t['typeMessage'],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: C.borderStrong),
                        ),
                      ),
                      onSubmitted: (_) => _send(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _send(context),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                          color: C.accent,
                          borderRadius: BorderRadius.circular(100)),
                      child: Text(t['send'],
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _send(BuildContext context) {
    context.app.sendChatLive(_controller.text);
    _controller.clear();
  }
}
