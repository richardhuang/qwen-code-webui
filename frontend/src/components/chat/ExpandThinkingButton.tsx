import { ChevronDownIcon, ChevronUpIcon } from "@heroicons/react/24/outline";

interface ExpandThinkingButtonProps {
  isExpanded: boolean;
  onClick: () => void;
}

export function ExpandThinkingButton({
  isExpanded,
  onClick,
}: ExpandThinkingButtonProps) {
  return (
    <button
      onClick={onClick}
      className={`p-2 rounded-lg border transition-all duration-200 backdrop-blur-sm shadow-sm hover:shadow-md ${
        isExpanded
          ? "bg-blue-100/80 dark:bg-blue-900/80 border-blue-300 dark:border-blue-700"
          : "bg-white/80 dark:bg-slate-800/80 border-slate-200 dark:border-slate-700 hover:bg-white dark:hover:bg-slate-800"
      }`}
      aria-label={isExpanded ? "Collapse thinking by default" : "Expand thinking by default"}
      title={isExpanded ? "Collapse thinking by default" : "Expand thinking by default"}
    >
      {isExpanded ? (
        <ChevronUpIcon className="w-4 h-4 text-blue-600 dark:text-blue-400" />
      ) : (
        <ChevronDownIcon className="w-4 h-4 text-slate-600 dark:text-slate-400" />
      )}
    </button>
  );
}