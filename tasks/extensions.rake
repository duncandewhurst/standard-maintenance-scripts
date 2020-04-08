namespace :extensions do
  desc 'Discover new extensions on GitHub'
  task :discover do
    content = open('https://docs.google.com/spreadsheets/d/e/2PACX-1vS6NmEt61T-0Vvg0I0XQiIuQVZXOfE3tmDdPb5_HKTiVR5FyKMc3JJNIQAxq5rHbr5ok0dqdQrREGEs/pub?output=csv').read
    seen = CSV.parse(content, headers: true).map{ |row| row['URL'] }

    exclude = '-org:open-contracting-extensions -org:open-contracting -org:open-contracting-archive'
    items = client.search_code("filename:release-schema.json path:/ #{exclude}", per_page: 100).items
    items += client.search_code("code title description language:csv path:codelists #{exclude}", per_page: 100).items

    names = ['timgdavies'] + client.org_members('open-contracting').map{ |member| member.login.downcase }

    items.reject! do |item|
      names.include?(item.repository.owner.login.downcase) || seen.include?(item.repository.html_url)
    end

    items.map! do |item|
      [
        item.repository.name.gsub(/\Aocds[_-]|[_-]extension\b/, ''),
        item.repository.html_url,
        item.repository.owner.login.downcase,
      ]
    end

    CSV.new($stdout, col_sep: "\t") do |csv|
      items.uniq.sort.each do |item|
        csv << item
      end
    end
  end

  desc 'Download unregistered extensions'
  task :download_unregistered do
    basedir = variables('BASEDIR')[0]

    content = open('https://docs.google.com/spreadsheets/d/e/2PACX-1vS6NmEt61T-0Vvg0I0XQiIuQVZXOfE3tmDdPb5_HKTiVR5FyKMc3JJNIQAxq5rHbr5ok0dqdQrREGEs/pub?output=csv').read
    CSV.parse(content, headers: true).each do |row|
      if row['Decision'] != 'Never'
        url = row['URL']
        parsed = URI.parse(url)
        directory = File.join(basedir, parsed.path)
        if !File.exist?(directory)
          `git clone #{url}.git #{directory}`
        end
      end
    end
  end

  desc 'Create forks of unregistered extensions'
  task :create_fork_unregistered do
    owner = variables('OWNER')[0]

    content = open('https://docs.google.com/spreadsheets/d/e/2PACX-1vS6NmEt61T-0Vvg0I0XQiIuQVZXOfE3tmDdPb5_HKTiVR5FyKMc3JJNIQAxq5rHbr5ok0dqdQrREGEs/pub?output=csv').read
    CSV.parse(content, headers: true).each do |row|
      if row['Owner'].downcase == owner
        url = row['URL']
        parsed = URI.parse(url)
        full_name = parsed.path[1..-1]

        client.fork(full_name)
      end
    end
  end

  desc 'Delete forks of unregistered extensions'
  task :delete_fork_unregistered do
    owner, user = variables('OWNER', 'USERNAME')

    content = open('https://docs.google.com/spreadsheets/d/e/2PACX-1vS6NmEt61T-0Vvg0I0XQiIuQVZXOfE3tmDdPb5_HKTiVR5FyKMc3JJNIQAxq5rHbr5ok0dqdQrREGEs/pub?output=csv').read
    CSV.parse(content, headers: true).each do |row|
      if row['Owner'].downcase == owner
        url = row['URL']
        parsed = URI.parse(url)
        full_name = "#{user}/#{parsed.path.split('/')[-1]}"

        if client.repository?(full_name)
          client.delete_repo(full_name)
        end
      end
    end
  end

  desc 'Report the language and length of the documentation of unregistered extensions'
  task :documentation_language_length do
    basedir = variables('BASEDIR')[0]

    Dir[File.join(basedir, '*', '*')].each do |directory|
      text = File.read(File.join(directory, 'README.md'))
      text_without_examples = text.gsub(/```[^`]+```/m, '')
      size = text_without_examples.size

      if size > 128 # somewhat arbitrary power of two
        # Ignore JSON examples, unless the readme is otherwise too short.
        text = text_without_examples
      else
        # Ignore JSON keys.
        text = text.gsub(/"[^"]+":/, '')
      end

      language = CLD.detect_language(text)[:code]
      case language
      when 'gl' # Galician
        language = 'es'
      when 'en'
        language = '  '
      end

      if size < 200
        size = size.to_s.red
      else
        size = size.to_s.blue
      end

      puts '%s  %13s  %s' % [language, size, directory.sub(basedir, '')]
    end
  end
end
