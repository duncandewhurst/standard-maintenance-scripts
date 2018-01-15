namespace :org do
  desc 'Lists organization members not employed by the Open Contracting Partnership or its helpdesk teams'
  task :members do
    # Last updated 2018-01-15
    known_members = [
      # Open Contracting Partnership
      # https://www.open-contracting.org/about/team/
      'jpmckinney', # James McKinney
      'lindseyam', # Lindsey Marchessault

      # Open Data Services Co-op
      # http://opendataservices.coop
      'bjwebb', # Ben Webb
      'kindly', # David Raznick
      'duncandewhurst', # Duncan Dewhurst
      'edugomez', # Eduardo Gomez
      'scatteredink', # Jack Lord
      'julijahansen', # Julija Hansen
      'robredpath', # Rob Redpath
      'timgdavies', # Tim Davies

      # Iniciativa Latinoamericana por los Datos Abiertos
      # https://idatosabiertos.org/acerca-de-nosotros/
      'cdemidchuk', # Catalina Demidchuk
      'juanpane', # Juan Pane
      'scrollif', # Fabrizio Scrollini
      'tlacoyodefrijol', # Oscar Montiel
      'yolile', # Yohanna Lisnichuk
    ]

    people = client.org_members(organization) + client.org_invitations(organization, accept: 'application/vnd.github.korra-preview')

    names = people.map{ |member| member.login.downcase }

    puts names - known_members

    difference = known_members - names
    if difference.any?
      puts "remove from tasks/org.rake: #{difference.join(', ')}"
    end
  end
end
