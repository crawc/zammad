# Copyright (C) 2012-2016 Zammad Foundation, http://zammad-foundation.org/
module Ticket::SearchIndex

=begin

lookup name of ref. objects

  ticket = Ticket.find(123)
  result = ticket.search_index_attribute_lookup

returns

  attributes # object with lookup data

=end

  def search_index_attribute_lookup
    attributes = super
    return if !attributes

    # collect article data
    # add tags
    tags = Tag.tag_list(object: 'Ticket', o_id: id)
    if tags && !tags.empty?
      attributes[:tag] = tags
    end

    # list ignored file extentions
    attachments_ignore = Setting.get('es_attachment_ignore') || [ '.png', '.jpg', '.jpeg', '.mpeg', '.mpg', '.mov', '.bin', '.exe' ]

    # max attachment size
    attachment_max_size_in_mb = Setting.get('es_attachment_max_size_in_mb') || 40

    # collect article data
    articles = Ticket::Article.where(ticket_id: id)
    attributes['article'] = []
    articles.each { |article|
      article_attributes = article.attributes

      # remove note needed attributes
      ignore = %w(message_id_md5)
      ignore.each { |attribute|
        article_attributes.delete(attribute)
      }

      # lookup attributes of ref. objects (normally name and note)
      article_attributes = article.search_index_attribute_lookup

      # index raw text body
      if article_attributes['content_type'] && article_attributes['content_type'] == 'text/html' && article_attributes['body']
        article_attributes['body'] = article_attributes['body'].html2text
      end

      # lookup attachments
      article.attachments.each { |attachment|
        if !article_attributes['attachment']
          article_attributes['attachment'] = []
        end

        # check file size
        next if !attachment.content
        next if attachment.content.size / 1024 > attachment_max_size_in_mb * 1024

        # check ignored files
        next if !attachment.filename

        filename_extention = attachment.filename.downcase
        filename_extention.gsub!(/^.*(\..+?)$/, '\\1')

        next if attachments_ignore.include?(filename_extention.downcase)

        data = {
          '_name'    => attachment.filename,
          '_content' => Base64.encode64(attachment.content)
        }
        article_attributes['attachment'].push data
      }
      attributes['article'].push article_attributes
    }

    attributes
  end

end
