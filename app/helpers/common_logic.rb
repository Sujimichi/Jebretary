module CommonLogic

  def remove_message_from_temp_store keys
    keys = [keys] unless keys.is_a?(Array)
    messages = self.commit_messages
    keys.each{|key| messages.delete(key) }   
    self.commit_messages = messages
  end

  def commit_messages
    messages = super
    return {} if messages.blank?
    h = JSON.parse(messages)
    HashWithIndifferentAccess.new(h)
  end

  def commit_messages= messages
    messages = messages.to_json unless messages.blank?
    messages = nil if messages.blank?
    super messages
  end

end
