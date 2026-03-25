class UserService
  def self.find_by_email(email)
    # クラスメソッド
    User.find_by(email: email)
  end

  def self.create_from_oauth(data)
    new(name: data[:name], email: data[:email])
  end

  def initialize(name:, email:)
    @name = name
    @email = email
  end

  def full_name
    @name
  end

  def contact_email
    @email
  end
end
