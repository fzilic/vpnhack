def get_user_confirmation
  puts "[Y/N]:\n" 
  answer = nil

  begin
    answer = gets 
  end while ![ 'Y', 'y', 'N', 'n' ].include? answer.chomp 

  return [ 'Y', 'y' ].include? answer.chomp
end
