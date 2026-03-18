import { ArrowsRightLeftIcon } from "@heroicons/react/24/outline";
import { useSettings } from "../../hooks/useSettings";

interface ToggleWebUIComponentsButtonProps {
  onClick?: () => void;
}

export function ToggleWebUIComponentsButton({
  onClick,
}: ToggleWebUIComponentsButtonProps) {
  const { experimental, updateSettings } = useSettings();
  const isEnabled = experimental.useWebUIComponents;

  const handleClick = () => {
    updateSettings({
      experimental: {
        ...experimental,
        useWebUIComponents: !isEnabled,
      },
    });
    onClick?.();
  };

  return (
    <button
      onClick={handleClick}
      className={`p-2 rounded-lg border transition-all duration-200 backdrop-blur-sm shadow-sm hover:shadow-md ${
        isEnabled
          ? "bg-purple-100/80 dark:bg-purple-900/30 border-purple-200 dark:border-purple-700 hover:bg-purple-100 dark:hover:bg-purple-900/50"
          : "bg-white/80 dark:bg-slate-800/80 border-slate-200 dark:border-slate-700 hover:bg-white dark:hover:bg-slate-800"
      }`}
      aria-label={`Toggle WebUI Components. Currently ${isEnabled ? "enabled" : "disabled"}. Click to ${isEnabled ? "disable" : "enable"}.`}
      title={`Toggle WebUI Components (${isEnabled ? "Enabled" : "Disabled"})`}
    >
      <ArrowsRightLeftIcon
        className={`w-4 h-4 ${
          isEnabled
            ? "text-purple-600 dark:text-purple-400"
            : "text-slate-600 dark:text-slate-400"
        }`}
      />
    </button>
  );
}
