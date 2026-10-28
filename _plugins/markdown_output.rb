# Writes a Markdown copy of every Markdown page next to its HTML page, plus sitemap-markdown.xml.
#
# The copy is the page source with Liquid rendered (so {{site.baseurl}} links and includes resolve)
# but not converted to HTML, under a YAML frontmatter block with the page's own metadata.
# /docs/x/y.html gets /docs/x/y.md; /docs/x/ (index.html) gets /docs/x/index.md.
require "json"
require "time"

module MarkdownOutput
  FIELDS = %w[title description summary sidebar tags category].freeze
  # Canonical product names for the frontmatter values and /docs/<dir>/ paths used on docs.digdir.no.
  PRODUCTS = {
    "idporten" => "ID-porten", "id-porten" => "ID-porten",
    "maskinporten" => "Maskinporten", "maskinporten_sidebar" => "Maskinporten",
    "ansattporten" => "Ansattporten",
    "kontaktregisteret" => "KRR", "krr" => "KRR", "kontakt- og reservasjonsregisteret" => "KRR",
    "eformidling" => "eFormidling", "einnsyn" => "eInnsyn", "elma" => "ELMA",
    "digitalpostkasse" => "Digital postkasse", "digital postkasse" => "Digital postkasse",
    "selvbetjening" => "Selvbetjening", "esignering" => "eSignering", "lommebok" => "Lommebok",
    "egovernment" => "eGovernment", "general" => "general",
  }.freeze
  MARKDOWN = %w[.md .markdown].freeze

  module_function

  def markdown_page?(doc)
    MARKDOWN.include?(doc.extname.to_s.downcase) && doc.data["search"] != false &&
      doc.data["sitemap"] != false && !doc.data["redirect_to"]
  end

  # Liquid-rendered source, as Jekyll's renderer would produce before conversion.
  def render_source(doc, payload)
    renderer = Jekyll::Renderer.new(doc.site, doc, payload)
    info = {
      registers: { site: doc.site, page: payload["page"] },
      strict_filters: doc.site.config.dig("liquid", "strict_filters"),
      strict_variables: doc.site.config.dig("liquid", "strict_variables"),
    }
    renderer.render_liquid(doc.content, payload, info, doc.path)
  end

  def frontmatter(doc)
    fields = FIELDS.each_with_object({}) do |key, out|
      value = doc.data[key]
      next if value.nil? || (value.respond_to?(:empty?) && value.empty?)
      out[key] = value.is_a?(String) ? value.strip : value
    end
    product = product(doc)
    fields["product"] = product if product
    fields["lastmod"] = doc.data["last_modified_at"].iso8601 if doc.data["last_modified_at"].respond_to?(:iso8601)
    # JSON scalars are valid YAML, so titles with ':' or quotes stay parseable.
    "---\n" + fields.map { |k, v| "#{k}: #{JSON.generate(v)}" }.join("\n") + "\n---\n\n"
  end

  # The page's own product, normalised; else the product of its /docs/<dir>/ path.
  def product(doc)
    raw = doc.data["product"].to_s.strip
    dir = doc.url[%r{\A/docs/([^/]+)/}, 1].to_s
    PRODUCTS[raw.downcase] || PRODUCTS[dir.downcase] || (raw.empty? ? nil : raw)
  end

  def markdown_url(url)
    return url + "index.md" if url.end_with?("/")
    url.sub(/\.html\z/, "") + ".md"
  end
end

Jekyll::Hooks.register [:documents, :pages], :pre_render do |doc, payload|
  next unless MarkdownOutput.markdown_page?(doc)
  doc.data["markdown_output"] = MarkdownOutput.render_source(doc, payload)
end

Jekyll::Hooks.register :site, :post_write do |site|
  base = site.config["url"].to_s.chomp("/") + site.config["baseurl"].to_s.chomp("/")
  entries = []
  (site.documents + site.pages).each do |doc|
    body = doc.data["markdown_output"]
    next unless body
    url = MarkdownOutput.markdown_url(doc.url)
    path = File.join(site.dest, url)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, MarkdownOutput.frontmatter(doc) + body.strip + "\n")
    entries << [base + url, doc.data["last_modified_at"]]
  end
  urls = entries.sort.map do |loc, lastmod|
    mod = lastmod.respond_to?(:iso8601) ? "<lastmod>#{lastmod.iso8601}</lastmod>" : ""
    "<url><loc>#{loc.encode(xml: :text)}</loc>#{mod}</url>"
  end
  File.write(
    File.join(site.dest, "sitemap-markdown.xml"),
    %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n#{urls.join("\n")}\n</urlset>\n),
  )
  Jekyll.logger.info "Markdown output:", "#{entries.size} pages and sitemap-markdown.xml"
end
