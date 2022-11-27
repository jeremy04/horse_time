# require 'puppeteer-ruby'
# require 'nokogiri'

# def scrape(team)
#     options = {
#       headless: true,
#       slow_mo:  50,
#       args: [
#         '--window-size=1280,800',
#         '--no-sandbox',
#         '--disable-setuid-sandbox',
#         '--disable-infobars',
#         '--ignore-certifcate-errors'
#     ]
#     }

#     Puppeteer.launch **options do |browser|
#       page = browser.new_page
#       page.viewport = Puppeteer::Viewport.new(width: 1280, height: 800)
#       page.evaluate_on_new_document(<<~JAVASCRIPT)
#       () => {
#         Object.defineProperty(navigator, "webdriver", {get: () => false});
#         Object.defineProperty(window, "webdriver", {get: () => false});
#         window.navigator.chrome = {
#             runtime: {},
#         };
#         Object.defineProperty(navigator, 'platform', {
#             get: () => "Win32",
#         });

#         Object.defineProperty(navigator, 'plugins', {
#             get: () => [1, 2],
#         });

#       }
#       JAVASCRIPT
#       page.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.39 Safari/537.36"
#       page.goto("https://dailyfaceoff.com/teams/philadelphia-flyers/line-combinations/", wait_until: 'domcontentloaded')
#       p page.content
#       doc = Nokogiri::HTML(page.content)
#       forwards = doc.css("#forwards").css(".player-name").map { |name| name.text }
#       defense = doc.css("#defense").css(".player-name").map { |name| name.text }
#       p forwards + defense
#     end
#   end
# scrape("foo")
