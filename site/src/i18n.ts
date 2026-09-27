export type Lang = 'en' | 'ko';

/** One scripted wild battle in the hero's notch. */
export interface Encounter {
  id: number;
  name: string;
  level: number;
  move: string;
  appeared: string;
  fainted: string;
}

const en = {
  htmlLang: 'en',
  title: 'pokove: a Pokémon journey in your MacBook notch',
  description:
    'pokove is a notch app for Mac. While Claude Code or Codex works, your Pokémon travel through Kanto in the notch. It also shows what your agents are doing and lets you answer them from there.',
  skip: 'Skip to content',
  menu: { adventure: 'Adventure', agents: 'Agents', notch: 'Notch', download: 'Download', github: 'GitHub' },
  otherLang: { label: '한국어', path: 'ko/' },

  hero: {
    title: 'While Claude codes, your Pokémon train.',
    lede:
      'pokove puts a Pokémon journey in your MacBook notch. Give Claude Code or Codex a task and your party heads out on its own. When the agent stops, so do they.',
    download: 'Download for Mac',
    source: 'Source on GitHub',
    fine: 'Free. Needs a Mac with Apple silicon and macOS 15 or later.',
  },

  battle: {
    tabs: ['Challenge', 'Pokédex', 'Gacha'],
    chapter: 'Chapter 2',
    badges: 'Badges 1/8',
    toGym: (n: number) => `${n} more to Misty`,
    party: [
      { id: 4, name: 'Charmander', level: 14 },
      { id: 16, name: 'Pidgey', level: 12 },
      { id: 25, name: 'Pikachu', level: 13 },
    ],
    moves: ['Ember', 'Scratch'],
    used: (who: string, move: string) => `${who} used ${move}!`,
    foes: [
      { id: 19, name: 'Rattata', level: 11, move: 'Tackle', appeared: 'A wild Rattata appeared!', fainted: 'Rattata fainted!' },
      { id: 21, name: 'Spearow', level: 12, move: 'Peck', appeared: 'A wild Spearow appeared!', fainted: 'Spearow fainted!' },
      { id: 23, name: 'Ekans', level: 12, move: 'Poison Sting', appeared: 'A wild Ekans appeared!', fainted: 'Ekans fainted!' },
    ] as Encounter[],
  },

  adventure: {
    title: 'Kanto, one station at a time',
    body:
      'Each chapter is a line of ten stations with a gym leader at the end, from Brock all the way to the Elite Four. The line only moves while an agent is working, so a long refactor makes for a long trip.',
    chapter: 'Chapter 5',
    gym: 'Koga',
    features: [
      {
        art: 'badge',
        name: 'Gym leaders',
        text: 'Clear the line and the leader is waiting. You see their team and your odds before you tap Challenge.',
      },
      {
        art: 'master-ball',
        name: 'Legendaries',
        text: 'Snorlax, Zapdos, Articuno, Moltres and Mewtwo sit on side branches. Beat one and it joins you.',
      },
      {
        art: 'escape-rope',
        name: 'Daily dungeon',
        text: 'Five floors of the day’s type in Easy, Normal and Hard. Each tier pays out once a day and resets at 4 a.m.',
      },
      {
        art: 'poke-ball',
        name: 'New teammates',
        text: 'Every 20 minutes or so of agent work, someone from the area joins. Stardust buys three Poké Balls; open one and whoever’s inside is yours.',
      },
    ],
    noLoss: 'Losing costs nothing. The party goes back to training and tries again when it’s ready.',
    off: 'You can turn the adventure off in Settings.',
    disclaimer:
      'Unofficial fan project, not affiliated with or endorsed by Nintendo, Game Freak, Creatures or The Pokémon Company. Pokémon data and sprites come from PokéAPI while the app runs. None are included in pokove.',
  },

  demo: {
    agents: 'Agents',
    working: 'working',
    waiting: (n: number) => `${n} waiting`,
    today: 'Today 12 turns · 48m',
    wantsToUse: (project: string, tool: string) => `${project} wants to use ${tool}`,
    deny: 'Deny',
    always: 'Always Allow',
    allow: 'Allow',
    allowed: 'Allowed',
    denied: 'Denied from the notch',
    sessions: [
      { title: 'pokove landing page', step: 'Editing Hero.astro' },
      { title: 'api-server', step: 'Running tests' },
    ],
    requests: [
      { project: 'pokove', tool: 'Bash', detail: 'pnpm build', after: 'Running pnpm build' },
      { project: 'pokove', tool: 'Edit', detail: 'src/components/Notch.astro', after: 'Editing Notch.astro' },
      { project: 'pokove', tool: 'Bash', detail: 'git push origin main', after: 'Pushing to origin' },
    ],
    battery: '88%',
    tabs: ['Now Playing', 'Calendar', 'To-dos', 'Clipboard', 'Agents', 'Adventure'],
    try: 'Try it: allow or deny the request.',
  },

  agents: {
    title: 'Claude and Codex, up top',
    body:
      'The notch also keeps an eye on your coding agents. It reads the session files Claude Code and Codex already write, so there’s nothing to set up. The desktop apps, the CLIs and the IDE extensions all work.',
    states: [
      { name: 'Working', text: 'The spark spins next to how long the turn has taken.' },
      { name: 'Needs you', text: 'A permission prompt shows up in the notch. Allow or deny it there and keep typing.' },
      { name: 'Done', text: 'A banner drops down with the project, the time and Claude’s last message.' },
    ],
    hooks:
      'Answering from the notch needs Claude Code hooks. Click Install Hooks in Settings → Claude Code; your settings file is backed up first.',
  },

  pages: {
    title: 'And the usual notch things',
    body: 'Swipe down on the notch or click the icons along its top to switch pages.',
    items: [
      { key: 'media', name: 'Now Playing', text: 'Artwork, a scrubber and playback controls for Music, Spotify or whatever is playing.' },
      { key: 'calendar', name: 'Calendar', text: 'Today’s events next to the month.' },
      { key: 'todos', name: 'To-dos', text: 'A short list. Press Return and the next line is ready.' },
      { key: 'clipboard', name: 'Clipboard', text: 'Everything you copied, newest first. Passwords are never kept.' },
    ],
    more: 'It also takes over the volume and brightness HUD and shows your AirPods battery when they connect.',
    track: { title: 'Evening Tide', artist: 'The Coves', elapsed: '1:10', left: '-3:07' },
    calendar: { weekday: 'Sunday', month: 'September', events: [['10:00', 'Design review'], ['14:30', 'Ship the landing page'], ['19:00', 'Dinner']] },
    todos: { count: 'left', items: ['Record the demo', 'Write release notes', 'Answer issues'], done: 'Package pokove.zip', add: 'New To-do' },
    clips: [['text', 'brew install --cask pokove', 'Terminal'], ['link', 'github.com/geonhwiii/pokove', 'Safari'], ['color', '#5A48EC', 'Figma']],
  },

  download: {
    title: 'Get pokove',
    button: 'Download pokove.zip',
    meta: 'Version 1.0. Apple silicon, macOS 15 or later.',
    releases: 'All releases',
    steps: [
      'Unzip it and drag pokove into Applications.',
      'Open it. macOS will say it can’t check the developer yet. Go to System Settings → Privacy & Security and click Open Anyway.',
      'Pick a starter. The notch opens when you hover it.',
      'Optional: click Install Hooks in Settings → Claude Code to answer Claude from the notch.',
    ],
    sourceTitle: 'Build it yourself',
    sourceText: 'You need Xcode 27. The script builds a Release copy and puts it in ~/Applications.',
  },

  footer: {
    marks:
      'Pokémon is a trademark of Nintendo, Creatures and Game Freak. Claude is a trademark of Anthropic. Codex is a trademark of OpenAI.',
    github: 'Source on GitHub',
  },
};

type Strings = typeof en;

const ko: Strings = {
  htmlLang: 'ko',
  title: 'pokove: MacBook 노치 속 포켓몬 모험',
  description:
    'pokove는 Mac 노치 앱이에요. Claude Code나 Codex가 일하는 동안 노치 속 포켓몬이 관동 지방을 여행해요. 에이전트가 뭘 하는지 보여 주고, 요청에도 노치에서 바로 답할 수 있어요.',
  skip: '본문으로 건너뛰기',
  menu: { adventure: '모험', agents: '에이전트', notch: '노치', download: '다운로드', github: 'GitHub' },
  otherLang: { label: 'English', path: '' },

  hero: {
    title: 'Claude가 일하면 포켓몬이 자라요.',
    lede:
      'pokove(포코브)는 MacBook 노치에 포켓몬 모험을 넣어 줘요. Claude Code나 Codex에 일을 맡기면 파티가 알아서 길을 떠나고, 에이전트가 멈추면 같이 쉬어요.',
    download: 'Mac용 다운로드',
    source: 'GitHub에서 소스 보기',
    fine: '무료예요. Apple 실리콘 Mac, macOS 15 이상이 필요해요.',
  },

  battle: {
    tabs: ['도전', '도감', '뽑기'],
    chapter: '2장',
    badges: '배지 1/8',
    toGym: (n: number) => `이슬까지 ${n}정거장`,
    party: [
      { id: 4, name: '파이리', level: 14 },
      { id: 16, name: '구구', level: 12 },
      { id: 25, name: '피카츄', level: 13 },
    ],
    moves: ['불꽃세례', '할퀴기'],
    used: (who: string, move: string) => `${who}의 ${move}!`,
    foes: [
      { id: 19, name: '꼬렛', level: 11, move: '몸통박치기', appeared: '야생 꼬렛이 나타났다!', fainted: '꼬렛은 쓰러졌다!' },
      { id: 21, name: '깨비참', level: 12, move: '쪼기', appeared: '야생 깨비참이 나타났다!', fainted: '깨비참은 쓰러졌다!' },
      { id: 23, name: '아보', level: 12, move: '독침', appeared: '야생 아보가 나타났다!', fainted: '아보는 쓰러졌다!' },
    ],
  },

  adventure: {
    title: '관동 지방을 한 정거장씩',
    body:
      '장마다 열 개의 정거장이 있고, 끝에서 체육관 관장이 기다려요. 웅부터 사천왕까지 이어져요. 노선은 에이전트가 일할 때만 움직여서, 리팩터링이 길어지면 여행도 길어져요.',
    chapter: '5장',
    gym: '독수',
    features: [
      { art: 'badge', name: '체육관 관장', text: '노선을 다 달리면 관장이 기다려요. 상대 팀과 이길 확률을 확인하고 도전을 누르면 돼요.' },
      { art: 'master-ball', name: '전설의 포켓몬', text: '잠만보, 썬더, 프리져, 파이어, 뮤츠가 갈림길에 있어요. 이기면 동료가 돼요.' },
      { art: 'escape-rope', name: '데일리 던전', text: '그날 타입의 5층짜리 던전이에요. 쉬움, 노말, 어려움 보상을 하루 한 번씩 받고, 새벽 4시에 초기화돼요.' },
      { art: 'poke-ball', name: '새 동료', text: '에이전트가 20분쯤 일할 때마다 근처 포켓몬이 합류해요. 별의모래로 몬스터볼 세 개를 사서 하나를 열면, 안에 있던 포켓몬이 들어와요.' },
    ],
    noLoss: '져도 잃는 건 없어요. 파티가 수련하다가 준비되면 다시 도전해요.',
    off: '모험은 설정에서 끌 수 있어요.',
    disclaimer:
      '비공식 팬 프로젝트예요. Nintendo, Game Freak, Creatures, The Pokémon Company와 관련이 없고 승인받지 않았어요. 포켓몬 데이터와 이미지는 앱이 실행될 때 PokéAPI에서 받아 오고, pokove에는 들어 있지 않아요.',
  },

  demo: {
    agents: '에이전트',
    working: '작업 중',
    waiting: (n: number) => `${n}개 대기 중`,
    today: '오늘 12회 · 48분',
    wantsToUse: (project: string, tool: string) => `${project} · ${tool} 사용 요청`,
    deny: '거부',
    always: '항상 허용',
    allow: '허용',
    allowed: '허용함',
    denied: '노치에서 거부함',
    sessions: [
      { title: 'pokove 랜딩 페이지', step: 'Hero.astro 편집 중' },
      { title: 'api-server', step: '테스트 실행 중' },
    ],
    requests: [
      { project: 'pokove', tool: 'Bash', detail: 'pnpm build', after: 'pnpm build 실행 중' },
      { project: 'pokove', tool: 'Edit', detail: 'src/components/Notch.astro', after: 'Notch.astro 편집 중' },
      { project: 'pokove', tool: 'Bash', detail: 'git push origin main', after: 'origin에 푸시 중' },
    ],
    battery: '88%',
    tabs: ['지금 재생 중', '캘린더', '할 일', '클립보드', '에이전트', '모험'],
    try: '직접 눌러 보세요. 요청을 허용하거나 거부할 수 있어요.',
  },

  agents: {
    title: 'Claude와 Codex도 노치에서',
    body:
      '노치는 코딩 에이전트도 지켜봐요. Claude Code와 Codex가 원래 남기는 세션 파일을 읽어서 따로 설정할 게 없어요. 데스크톱 앱, CLI, IDE 확장 모두 돼요.',
    states: [
      { name: '작업 중', text: '스파크가 돌고, 옆에 이번 턴이 얼마나 걸렸는지 나와요.' },
      { name: '확인 필요', text: '권한 요청이 노치에 떠요. 거기서 허용하거나 거부하고 하던 일을 계속하면 돼요.' },
      { name: '완료', text: '프로젝트, 걸린 시간, Claude의 마지막 말이 담긴 배너가 내려와요.' },
    ],
    hooks: '노치에서 답하려면 Claude Code 훅이 필요해요. 설정 → Claude Code에서 훅 설치를 누르면 기존 설정 파일을 백업한 뒤 추가해요.',
  },

  pages: {
    title: '노치에 있으면 좋은 것들',
    body: '노치를 아래로 쓸거나 위쪽 아이콘을 눌러 페이지를 바꿔요.',
    items: [
      { key: 'media', name: '지금 재생 중', text: '음악 앱이나 Spotify에서 재생 중인 곡의 앨범 아트, 재생 막대, 재생 버튼이 나와요.' },
      { key: 'calendar', name: '캘린더', text: '이번 달 달력 옆에 오늘 일정이 나와요.' },
      { key: 'todos', name: '할 일', text: '짧은 목록이에요. Return을 누르면 바로 다음 줄을 쓸 수 있어요.' },
      { key: 'clipboard', name: '클립보드', text: '복사한 것을 최신순으로 모아 둬요. 비밀번호는 남기지 않아요.' },
    ],
    more: '음량·밝기 표시도 노치에 그리고, AirPods를 연결하면 배터리를 보여 줘요.',
    track: { title: 'Evening Tide', artist: 'The Coves', elapsed: '1:10', left: '-3:07' },
    calendar: { weekday: '일요일', month: '9월', events: [['10:00', '디자인 리뷰'], ['14:30', '랜딩 페이지 배포'], ['19:00', '저녁 약속']] },
    todos: { count: '남음', items: ['데모 녹화', '릴리스 노트 쓰기', '이슈 답장'], done: 'pokove.zip 만들기', add: '새로운 할 일' },
    clips: [['text', 'brew install --cask pokove', '터미널'], ['link', 'github.com/geonhwiii/pokove', 'Safari'], ['color', '#5A48EC', 'Figma']],
  },

  download: {
    title: 'pokove 받기',
    button: 'pokove.zip 다운로드',
    meta: '버전 1.0. Apple 실리콘, macOS 15 이상.',
    releases: '모든 릴리스',
    steps: [
      '압축을 풀고 pokove를 응용 프로그램 폴더로 옮겨요.',
      '실행하면 macOS가 아직 개발자를 확인할 수 없다고 해요. 시스템 설정 → 개인정보 보호 및 보안에서 그래도 열기를 눌러요.',
      '스타팅 포켓몬을 골라요. 노치에 마우스를 올리면 열려요.',
      '원하면 설정 → Claude Code에서 훅 설치를 눌러 노치에서 Claude에게 답할 수 있어요.',
    ],
    sourceTitle: '직접 빌드하기',
    sourceText: 'Xcode 27이 필요해요. 스크립트가 Release 빌드를 만들어 ~/Applications에 넣어요.',
  },

  footer: {
    marks: '포켓몬은 Nintendo, Creatures, Game Freak의 상표예요. Claude는 Anthropic, Codex는 OpenAI의 상표예요.',
    github: 'GitHub에서 소스 보기',
  },
};

export const strings: Record<Lang, Strings> = { en, ko };
