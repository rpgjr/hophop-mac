import SwiftUI
import WebKit

/// Tags read from a page loaded in the app's own browser, for sites that block the server.
struct BrowserPage {
    let link: String
    let host: String
    let candidates: [Candidate]
}

/// Loads the job page in a browser view that stays out of sight, waits for it to finish, and reads its tags.
/// The page only appears when a site asks the user to pass a "are you human" check.
struct BrowserReaderSheet: View {
    let url: URL
    let onFinish: (BrowserPage?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var needsCheck = false

    var body: some View {
        VStack(spacing: 0) {
            if needsCheck {
                HStack {
                    Text("The site wants a quick check. Complete it below and HopHop continues by itself.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    cancelButton
                }
                .padding(12)
                Divider()
            }

            ZStack {
                BrowserWebView(url: url) {
                    needsCheck = true
                } onRead: { page in
                    onFinish(page)
                    dismiss()
                }
                .frame(width: needsCheck ? 780 : 1100, height: needsCheck ? 520 : 800)
                .frame(width: needsCheck ? 780 : 1, height: needsCheck ? 520 : 1, alignment: .topLeading)
                .clipped()
                .opacity(needsCheck ? 1 : 0.01)
                .allowsHitTesting(needsCheck)

                if !needsCheck {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Reading the job page…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        cancelButton
                    }
                }
            }
        }
        .frame(width: needsCheck ? 780 : 340, height: needsCheck ? 580 : 170)
    }

    private var cancelButton: some View {
        Button("Cancel", role: .cancel) {
            onFinish(nil)
            dismiss()
        }
        .keyboardShortcut(.cancelAction)
    }
}

private struct BrowserWebView: NSViewRepresentable {
    let url: URL
    let onChallenge: () -> Void
    let onRead: (BrowserPage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        web.load(URLRequest(url: url))
        context.coordinator.start(web)
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {}

    static func dismantleNSView(_ web: WKWebView, coordinator: Coordinator) {
        coordinator.task?.cancel()
    }

    @MainActor
    final class Coordinator {
        private let parent: BrowserWebView
        var task: Task<Void, Never>?

        init(_ parent: BrowserWebView) { self.parent = parent }

        func start(_ web: WKWebView) {
            task = Task { await poll(web) }
        }

        /// Checks once a second, for up to two minutes, until the page is past any check and has loaded.
        private func poll(_ web: WKWebView) async {
            for attempt in 0..<120 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }

                let title = (try? await web.evaluateJavaScript("document.title")) as? String ?? ""
                let state = (try? await web.evaluateJavaScript("document.readyState")) as? String ?? ""
                let blocked = title.lowercased().contains("just a moment")

                guard state == "complete", !title.isEmpty, !blocked else {
                    if blocked && attempt >= 6 { parent.onChallenge() }
                    continue
                }

                try? await Task.sleep(for: .seconds(1.5))
                if let json = (try? await web.evaluateJavaScript(Self.script)) as? String,
                   let page = Self.decode(json, link: web.url?.absoluteString ?? parent.url.absoluteString) {
                    parent.onRead(page)
                    return
                }
            }
            parent.onRead(nil)
        }

        private static func decode(_ json: String, link: String) -> BrowserPage? {
            struct Raw: Decodable {
                let host: String
                let candidates: [Candidate]
            }
            guard let raw = try? JSONDecoder().decode(Raw.self, from: Data(json.utf8)) else { return nil }
            let host = raw.host.lowercased()
            return BrowserPage(
                link: link,
                host: host.hasPrefix("www.") ? String(host.dropFirst(4)) : host,
                candidates: raw.candidates
            )
        }

        // Mirrors the server's PageMetadataReader: meta tags, known page elements, JobPosting data.
        private static let script = """
        (() => {
          const out = [], seen = new Set();
          const cut = v => v.length > 12000 ? v.slice(0, 12000) : v;
          document.querySelectorAll('meta[content]').forEach(m => {
            const key = m.getAttribute('property') || m.getAttribute('name') || '';
            const value = (m.getAttribute('content') || '').trim();
            if (key && value && !seen.has(key)) { seen.add(key); out.push({type: 'META', key, value: cut(value)}); }
          });
          ['h1', '.top-card-layout__title', '.topcard__org-name-link', '.topcard__flavor--bullet',
           '.description__job-criteria-item:nth-child(2) .description__job-criteria-text',
           '.show-more-less-html__markup',
           '[data-testid="jobsearch-JobInfoHeader-title"]', '[data-testid="inlineHeader-companyName"]',
           '[data-testid="inlineHeader-companyLocation"]', '#salaryInfoAndJobType', '#jobDescriptionText',
           '[data-automation="jobAdDetails"]',
           '.job-details-fit-level-preferences', '.job-details-jobs-unified-top-card__job-title',
           '.job-details-jobs-unified-top-card__company-name',
           '.job-details-jobs-unified-top-card__primary-description-container', '#job-details'].forEach(selector => {
            try {
              const el = document.querySelector(selector);
              const text = el && el.innerText ? el.innerText.trim() : '';
              if (text) out.push({type: 'CSS', key: selector, value: cut(text)});
            } catch (e) {}
          });
          const patterns = {
            salary: [/(₱|PHP|USD|MYR|SGD|RM|S\\$|\\$)\\s?\\d[\\d,]*|\\d[\\d,.]*\\s?k?\\s?(₱|PHP|USD|MYR|SGD)/i, 120],
            setup: [/\\b(hybrid|remote|work from home|wfh|on-?site)\\b/i, 120],
            employment_type: [/\\b(full[- ]?time|part[- ]?time|contract(or)?|temporary|freelance|internship)\\b/i, 60]
          };
          const ownText = el => Array.from(el.childNodes).filter(n => n.nodeType === 3).map(n => n.textContent).join(' ').replace(/\\s+/g, ' ').trim();
          const leaves = Array.from(document.body.querySelectorAll('*')).filter(el =>
            !['SCRIPT', 'STYLE', 'NOSCRIPT'].includes(el.tagName));
          Object.keys(patterns).forEach(key => {
            const [re, max] = patterns[key];
            const hit = leaves.find(el => {
              const text = ownText(el);
              return text && text.length <= max && re.test(text);
            });
            if (hit) out.push({type: 'PATTERN', key, value: cut(ownText(hit))});
          });
          const headingRe = /^(full\\s+)?job\\s+description$|^about\\s+(the|this)\\s+(job|role|position)$|^description$/i;
          for (const heading of leaves.filter(el => headingRe.test(ownText(el)))) {
            const title = ownText(heading);
            let box = heading, found = false;
            for (let level = 0; level < 4 && box.parentElement && !found; level++) {
              box = box.parentElement;
              let text = (box.innerText || '').trim();
              if (text.startsWith(title)) text = text.slice(title.length).trim();
              if (text.length >= 150) { out.push({type: 'PATTERN', key: 'description', value: cut(text)}); found = true; }
            }
            if (found) break;
          }
          const labelled = new Set();
          document.querySelectorAll('[data-automation], [data-testid]').forEach(el => {
            const text = (el.innerText || '').trim();
            const attr = el.hasAttribute('data-automation') ? 'data-automation' : 'data-testid';
            const selector = '[' + attr + '="' + el.getAttribute(attr) + '"]';
            if (text && text.length <= 120 && !labelled.has(selector) && labelled.size < 40) {
              labelled.add(selector);
              out.push({type: 'CSS', key: selector, value: cut(text)});
            }
          });
          const find = n => {
            if (Array.isArray(n)) { for (const c of n) { const f = find(c); if (f) return f; } return null; }
            if (n && typeof n === 'object') {
              const t = n['@type'];
              if (Array.isArray(t) ? t.includes('JobPosting') : t === 'JobPosting') return n;
              return find(n['@graph']);
            }
            return null;
          };
          let job = null;
          document.querySelectorAll('script[type="application/ld+json"]').forEach(s => {
            if (!job) { try { job = find(JSON.parse(s.textContent)); } catch (e) {} }
          });
          const walk = (n, path) => {
            if (n && typeof n === 'object') {
              if (Array.isArray(n)) n.forEach((c, i) => walk(c, path + '.' + i));
              else Object.keys(n).forEach(k => { if (!k.startsWith('@')) walk(n[k], path ? path + '.' + k : k); });
            } else if (n !== null && n !== undefined && path && String(n).trim()) {
              out.push({type: 'JSON_LD', key: path, value: cut(String(n))});
            }
          };
          if (job) walk(job, '');
          return JSON.stringify({host: location.hostname, candidates: out.slice(0, 150)});
        })()
        """
    }
}
