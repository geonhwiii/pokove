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
  otherLang: { label: '한국어', path: '' },

  hero: {
    title: 'While Claude codes, your Pokémon train.',
    lede: 'Your party travels in the MacBook notch while your agent works.',
    download: 'Download for Mac',
    source: 'Source on GitHub',
    fine: 'Free. Needs an Apple silicon Mac on macOS 15 or later.',
  },

  battle: {
    tabs: ['Challenge', 'Pokédex', 'Gacha'],
    chapter: 'Chapter 2',
    badges: 'Badges 1/8',
    toGym: (n: number) => (n === 1 ? "1 station to Misty's gym" : `${n} stations to Misty's gym`),
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
    body: 'The line only moves while your agent is working.',
    chapter: 'Chapter 5',
    features: [
      { art: 'badge', name: 'Gym leaders', text: 'Clear a chapter and its gym leader is ready for you.' },
      { art: 'master-ball', name: 'Legendaries', text: 'Beat one on a side branch and it joins your party.' },
      { art: 'escape-rope', name: 'Daily dungeons', text: 'Stardust and EXP, stage by stage, three tries a day.' },
      { art: 'poke-ball', name: 'New teammates', text: 'Someone new joins about every 20 minutes of work.' },
    ],
    note: 'Losing costs nothing, and you can turn the adventure off in Settings.',
    disclaimer:
      'pokove is an unofficial fan project, not affiliated with Nintendo, Game Freak, Creatures or The Pokémon Company, and its sprites load from PokéAPI at runtime instead of shipping with the app.',
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
    try: 'Try the buttons.',
  },

  agents: {
    title: 'Claude and Codex, up top',
    body: 'Your agents show up in the notch with nothing to set up.',
    states: [
      { name: 'Working', text: 'A spinning spark and the time so far.' },
      { name: 'Needs you', text: 'Allow or deny it right there.' },
      { name: 'Done', text: 'A banner with Claude’s last message.' },
    ],
    hooks: 'To answer from the notch, install hooks in Settings → Claude Code.',
  },

  pages: {
    title: 'And the usual notch things',
    body: 'Swipe down or click an icon to switch pages.',
    items: [
      { key: 'media', name: 'Now Playing', text: 'Play, pause and skip from the notch.' },
      { key: 'calendar', name: 'Calendar', text: 'Today’s events next to the month.' },
      { key: 'todos', name: 'To-dos', text: 'A short list to check off.' },
      { key: 'clipboard', name: 'Clipboard', text: 'What you copied, newest first, minus passwords.' },
    ],
    more: 'Volume, brightness and AirPods battery show up there too.',
    track: { title: 'Evening Tide', artist: 'The Coves', elapsed: '1:10', left: '-3:07' },
    calendar: { weekday: 'Sunday', month: 'September', events: [['10:00', 'Design review'], ['14:30', 'Ship the landing page'], ['19:00', 'Dinner']] },
    todos: { count: 'left', items: ['Record the demo', 'Write release notes', 'Answer issues'], done: 'Package pokove.zip', add: 'New To-do' },
    clips: [['text', 'brew install --cask pokove', 'Terminal'], ['link', 'github.com/geonhwiii/pokove', 'Safari'], ['color', '#5A48EC', 'Figma']],
  },

  downloading: {
    title: 'Downloading pokove',
    heading: 'pokove.zip is on its way',
    retry: 'Nothing yet?',
    retryLink: 'Download it again',
    back: 'Back to pokove',
  },

  download: {
    title: 'Get pokove',
    button: 'Download pokove.zip',
    meta: 'For Apple silicon and macOS 15 or later.',
    releases: 'All releases',
    steps: [
      'Unzip it and drag pokove into Applications.',
      'If macOS blocks it, go to System Settings → Privacy & Security and click Open Anyway.',
      'Pick a starter and you’re set.',
    ],
    sourceTitle: 'Build it yourself',
    sourceText: 'With Xcode 27, this installs it to ~/Applications.',
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
  otherLang: { label: 'English', path: 'en/' },

  hero: {
    title: 'Claude가 일하면 포켓몬이 자라요.',
    lede: '에이전트가 일하는 동안 MacBook 노치 속 파티가 여행해요.',
    download: 'Mac용 다운로드',
    source: 'GitHub에서 소스 보기',
    fine: '무료예요. Apple 실리콘 Mac과 macOS 15 이상이면 돼요.',
  },

  battle: {
    tabs: ['도전', '도감', '뽑기'],
    chapter: '2장',
    badges: '배지 1/8',
    toGym: (n: number) => `이슬 체육관까지 역 ${n}개`,
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
    body: '노선은 에이전트가 일할 때만 움직여요.',
    chapter: '5장',
    features: [
      { art: 'badge', name: '체육관 관장', text: '장을 다 지나면 그 장의 관장에게 도전할 수 있어요.' },
      { art: 'master-ball', name: '전설의 포켓몬', text: '갈림길에 숨어 있고, 이기면 동료가 돼요.' },
      { art: 'escape-rope', name: '데일리 던전', text: '별의모래와 경험치 던전을 한 단계씩, 하루 세 번 도전해요.' },
      { art: 'poke-ball', name: '새 동료', text: '에이전트가 20분쯤 일할 때마다 포켓몬이 합류해요.' },
    ],
    note: '져도 잃는 건 없고, 모험은 설정에서 끌 수 있어요.',
    disclaimer:
      'Nintendo, Game Freak, Creatures, The Pokémon Company와 관련 없는 비공식 팬 프로젝트이고, 포켓몬 이미지는 앱에 넣지 않고 실행할 때 PokéAPI에서 받아 와요.',
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
    try: '버튼을 직접 눌러 보세요.',
  },

  agents: {
    title: 'Claude와 Codex도 노치에서',
    body: '따로 설정하지 않아도 에이전트 상태가 노치에 떠요.',
    states: [
      { name: '작업 중', text: '스파크 옆에 걸린 시간이 나와요.' },
      { name: '확인 필요', text: '노치에서 바로 허용하거나 거부해요.' },
      { name: '완료', text: 'Claude의 마지막 말이 배너로 내려와요.' },
    ],
    hooks: '노치에서 답하려면 설정 → Claude Code에서 훅을 설치하면 돼요.',
  },

  pages: {
    title: '노치에 있으면 좋은 것들',
    body: '아래로 쓸거나 아이콘을 눌러 페이지를 바꿔요.',
    items: [
      { key: 'media', name: '지금 재생 중', text: '듣고 있는 곡을 노치에서 멈추고 넘겨요.' },
      { key: 'calendar', name: '캘린더', text: '이번 달 옆에 오늘 일정이 나와요.' },
      { key: 'todos', name: '할 일', text: '짧게 적고 하나씩 지워요.' },
      { key: 'clipboard', name: '클립보드', text: '복사한 걸 모아 두고, 비밀번호는 남기지 않아요.' },
    ],
    more: '음량, 밝기, AirPods 배터리도 노치에 떠요.',
    track: { title: 'Evening Tide', artist: 'The Coves', elapsed: '1:10', left: '-3:07' },
    calendar: { weekday: '일요일', month: '9월', events: [['10:00', '디자인 리뷰'], ['14:30', '랜딩 페이지 배포'], ['19:00', '저녁 약속']] },
    todos: { count: '남음', items: ['데모 녹화', '릴리스 노트 쓰기', '이슈 답장'], done: 'pokove.zip 만들기', add: '새로운 할 일' },
    clips: [['text', 'brew install --cask pokove', '터미널'], ['link', 'github.com/geonhwiii/pokove', 'Safari'], ['color', '#5A48EC', 'Figma']],
  },

  downloading: {
    title: 'pokove 다운로드',
    heading: 'pokove.zip을 받고 있어요',
    retry: '받아지지 않았나요?',
    retryLink: '다시 받기',
    back: 'pokove로 돌아가기',
  },

  download: {
    title: 'pokove 받기',
    button: 'pokove.zip 다운로드',
    meta: 'Apple 실리콘과 macOS 15 이상에서 돌아가요.',
    releases: '모든 릴리스',
    steps: [
      '압축을 풀고 pokove를 응용 프로그램 폴더로 옮겨요.',
      'macOS가 막으면 시스템 설정 → 개인정보 보호 및 보안에서 그래도 열기를 눌러요.',
      '스타팅 포켓몬을 고르면 끝이에요.',
    ],
    sourceTitle: '직접 빌드하기',
    sourceText: 'Xcode 27이 있으면 ~/Applications에 바로 설치돼요.',
  },

  footer: {
    marks: '포켓몬은 Nintendo, Creatures, Game Freak의 상표예요. Claude는 Anthropic, Codex는 OpenAI의 상표예요.',
    github: 'GitHub에서 소스 보기',
  },
};

export const strings: Record<Lang, Strings> = { en, ko };
